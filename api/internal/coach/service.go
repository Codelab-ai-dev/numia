package coach

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"numia-api/internal/database/sqlc"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
)

const systemPrompt = `Eres Numia, un coach financiero personal experto en finanzas personales para México.
Tu objetivo es ayudar a los usuarios a mejorar su salud financiera, alcanzar sus metas y manejar sus deudas de manera efectiva.

Principios clave:
- Habla siempre en español mexicano, de manera amigable y empática
- Da consejos prácticos y accionables adaptados al contexto financiero mexicano
- Considera factores como inflación en México, tasas de interés locales, y productos financieros disponibles en México
- Ayuda a priorizar metas y deudas usando metodologías probadas (bola de nieve, avalancha, etc.)
- Cuando el usuario comparte su situación financiera, analiza patrones de gasto y sugiere mejoras específicas
- Sé honesto pero motivador; celebra los logros del usuario
- Si el usuario tiene deudas de alto interés (como tarjetas de crédito), prioriza pagarlas
- Sugiere instrumentos de ahorro e inversión mexicanos cuando sea apropiado (CETES, fondos de inversión, etc.)

Recuerda: tu rol es ser un coach de confianza, no solo un chatbot. Personaliza tus respuestas basándote en el contexto financiero del usuario.`

// Service provides coach-related business logic.
type Service struct {
	queries *sqlc.Queries
	groq    *GroqClient
}

// NewService creates a new coach Service.
func NewService(q *sqlc.Queries, groq *GroqClient) *Service {
	return &Service{queries: q, groq: groq}
}

// numericToFloat64 converts pgtype.Numeric to float64.
func numericToFloat64(n pgtype.Numeric) float64 {
	f8, err := n.Float64Value()
	if err != nil {
		return 0
	}
	if !f8.Valid {
		return 0
	}
	return f8.Float64
}

// buildFinancialContext fetches the user's financial data and returns a context string.
func (s *Service) buildFinancialContext(ctx context.Context, pgID pgtype.UUID) string {
	var sb fmt.Stringer
	_ = sb

	contextParts := []string{}

	// Accounts
	accounts, err := s.queries.ListAccountsByUser(ctx, pgID)
	if err == nil && len(accounts) > 0 {
		acctStr := "Cuentas del usuario:\n"
		for _, a := range accounts {
			balance := numericToFloat64(a.Balance)
			acctStr += fmt.Sprintf("- %s (%s): $%.2f %s\n", a.Name, a.Type.String, balance, a.Currency)
		}
		contextParts = append(contextParts, acctStr)
	}

	// Active goals
	goals, err := s.queries.GetActiveGoalsSummary(ctx, pgID)
	if err == nil && len(goals) > 0 {
		goalStr := "Metas activas del usuario:\n"
		for _, g := range goals {
			target := numericToFloat64(g.TargetAmount)
			current := numericToFloat64(g.CurrentAmount)
			pct := 0.0
			if target > 0 {
				pct = (current / target) * 100
			}
			goalStr += fmt.Sprintf("- %s: $%.2f / $%.2f (%.1f%%)\n", g.Name, current, target, pct)
		}
		contextParts = append(contextParts, goalStr)
	}

	// Active debts
	debts, err := s.queries.GetActiveDebtsSummary(ctx, pgID)
	if err == nil && len(debts) > 0 {
		debtStr := "Deudas activas del usuario:\n"
		for _, d := range debts {
			total := numericToFloat64(d.TotalAmount)
			monthly := numericToFloat64(d.MonthlyPayment)
			debtStr += fmt.Sprintf("- %s: $%.2f (pago mensual: $%.2f)\n", d.Name, total, monthly)
		}
		contextParts = append(contextParts, debtStr)
	}

	// Recent transactions
	txs, err := s.queries.GetRecentTransactions(ctx, sqlc.GetRecentTransactionsParams{
		UserID: pgID,
		Limit:  10,
	})
	if err == nil && len(txs) > 0 {
		txStr := "Transacciones recientes del usuario:\n"
		for _, t := range txs {
			amount := numericToFloat64(t.Amount)
			desc := t.Description.String
			if desc == "" {
				desc = "Sin descripción"
			}
			category := t.Category.String
			if category == "" {
				category = "Sin categoría"
			}
			txStr += fmt.Sprintf("- %s: $%.2f (%s)\n", desc, amount, category)
		}
		contextParts = append(contextParts, txStr)
	}

	if len(contextParts) == 0 {
		return ""
	}

	result := "=== CONTEXTO FINANCIERO DEL USUARIO ===\n"
	for _, p := range contextParts {
		result += p + "\n"
	}
	result += "======================================\n"
	return result
}

// Chat handles a user message, streams the response, and saves messages.
// Returns conversationID, full assistant response, and any error.
func (s *Service) Chat(ctx context.Context, userID uuid.UUID, req ChatRequest, onToken func(string)) (conversationID string, fullResponse string, err error) {
	pgID := pgtype.UUID{Bytes: userID, Valid: true}

	var existingMessages []MessageJSON
	var convID pgtype.UUID

	if req.ConversationID != nil {
		// Fetch existing conversation
		cid, parseErr := uuid.Parse(*req.ConversationID)
		if parseErr != nil {
			return "", "", fmt.Errorf("invalid conversation_id: %w", parseErr)
		}
		conv, fetchErr := s.queries.GetConversation(ctx, sqlc.GetConversationParams{
			ID:     pgtype.UUID{Bytes: cid, Valid: true},
			UserID: pgID,
		})
		if fetchErr != nil {
			return "", "", fmt.Errorf("fetch conversation: %w", fetchErr)
		}
		convID = conv.ID
		if len(conv.Messages) > 0 {
			if jsonErr := json.Unmarshal(conv.Messages, &existingMessages); jsonErr != nil {
				existingMessages = []MessageJSON{}
			}
		}
	} else {
		// Create new conversation
		conv, createErr := s.queries.CreateConversation(ctx, sqlc.CreateConversationParams{
			UserID: pgID,
			Title:  pgtype.Text{},
		})
		if createErr != nil {
			return "", "", fmt.Errorf("create conversation: %w", createErr)
		}
		convID = conv.ID
	}

	conversationID = convID.String()

	// Build financial context
	financialContext := s.buildFinancialContext(ctx, pgID)

	// Build groq messages
	groqMsgs := []groqMessage{
		{Role: "system", Content: systemPrompt},
	}

	if financialContext != "" {
		groqMsgs = append(groqMsgs, groqMessage{
			Role:    "system",
			Content: financialContext,
		})
	}

	// Append existing conversation messages
	for _, m := range existingMessages {
		groqMsgs = append(groqMsgs, groqMessage{
			Role:    m.Role,
			Content: m.Content,
		})
	}

	// Append new user message
	groqMsgs = append(groqMsgs, groqMessage{
		Role:    "user",
		Content: req.Message,
	})

	// Stream via Groq
	var streamedResponse string
	streamErr := s.groq.StreamChat(ctx, groqMsgs, onToken, func(full string) {
		streamedResponse = full
	})
	if streamErr != nil {
		return conversationID, "", fmt.Errorf("stream chat: %w", streamErr)
	}
	fullResponse = streamedResponse

	// Append user message and assistant response to existing messages
	now := time.Now()
	updatedMessages := append(existingMessages,
		MessageJSON{Role: "user", Content: req.Message, Timestamp: now},
		MessageJSON{Role: "assistant", Content: fullResponse, Timestamp: now},
	)

	messagesBytes, jsonErr := json.Marshal(updatedMessages)
	if jsonErr != nil {
		return conversationID, fullResponse, fmt.Errorf("marshal messages: %w", jsonErr)
	}

	// Determine title (use first ~50 chars of first user message)
	var titlePg pgtype.Text
	if len(existingMessages) == 0 {
		title := req.Message
		if len(title) > 50 {
			title = title[:50] + "..."
		}
		titlePg = pgtype.Text{String: title, Valid: true}
	}

	// Save messages back to DB
	_, updateErr := s.queries.UpdateConversationMessages(ctx, sqlc.UpdateConversationMessagesParams{
		ID:           convID,
		UserID:       pgID,
		Messages:     messagesBytes,
		MessageCount: int32(len(updatedMessages)),
		Title:        titlePg,
	})
	if updateErr != nil {
		return conversationID, fullResponse, fmt.Errorf("update conversation: %w", updateErr)
	}

	return conversationID, fullResponse, nil
}

const insightPrompt = `Eres Numia, coach financiero personal para México.
Con base en el contexto financiero del usuario, genera UN solo insight breve, accionable y motivador.
Reglas estrictas:
- Máximo 160 caracteres, una sola frase.
- En español mexicano, tono cercano.
- Concreto y específico (menciona cifras o acciones cuando ayude).
- Sin markdown, sin comillas, sin emojis, sin saludos. Devuelve solo la frase.`

// GenerateInsight produces a single short, actionable financial insight for the
// user based on their current financial context. Non-streaming.
func (s *Service) GenerateInsight(ctx context.Context, userID uuid.UUID) (string, error) {
	pgID := pgtype.UUID{Bytes: userID, Valid: true}

	financialContext := s.buildFinancialContext(ctx, pgID)

	userMsg := "Genera mi insight financiero de hoy."
	if financialContext == "" {
		userMsg = "Aún no tengo datos financieros registrados. Dame un consejo breve para empezar a organizar mis finanzas."
	}

	groqMsgs := []groqMessage{
		{Role: "system", Content: insightPrompt},
	}
	if financialContext != "" {
		groqMsgs = append(groqMsgs, groqMessage{Role: "system", Content: financialContext})
	}
	groqMsgs = append(groqMsgs, groqMessage{Role: "user", Content: userMsg})

	var response string
	err := s.groq.StreamChat(ctx, groqMsgs, func(string) {}, func(full string) {
		response = full
	})
	if err != nil {
		return "", fmt.Errorf("generate insight: %w", err)
	}
	return response, nil
}

// ListConversations returns recent conversations for a user.
func (s *Service) ListConversations(ctx context.Context, userID uuid.UUID, limit int32) ([]ConversationListItem, error) {
	pgID := pgtype.UUID{Bytes: userID, Valid: true}
	rows, err := s.queries.ListConversations(ctx, sqlc.ListConversationsParams{
		UserID: pgID,
		Limit:  limit,
	})
	if err != nil {
		return nil, err
	}

	items := make([]ConversationListItem, 0, len(rows))
	for _, r := range rows {
		item := ConversationListItem{
			ID:           r.ID.String(),
			MessageCount: r.MessageCount,
			UpdatedAt:    r.UpdatedAt.Time,
		}
		if r.Title.Valid {
			v := r.Title.String
			item.Title = &v
		}
		items = append(items, item)
	}
	return items, nil
}

// GetConversation returns a single conversation with its messages.
func (s *Service) GetConversation(ctx context.Context, userID uuid.UUID, convID uuid.UUID) ([]MessageJSON, error) {
	pgID := pgtype.UUID{Bytes: userID, Valid: true}
	conv, err := s.queries.GetConversation(ctx, sqlc.GetConversationParams{
		ID:     pgtype.UUID{Bytes: convID, Valid: true},
		UserID: pgID,
	})
	if err != nil {
		return nil, err
	}

	var messages []MessageJSON
	if len(conv.Messages) > 0 {
		if jsonErr := json.Unmarshal(conv.Messages, &messages); jsonErr != nil {
			return nil, fmt.Errorf("unmarshal messages: %w", jsonErr)
		}
	}
	return messages, nil
}

// DeleteConversation removes a conversation owned by userID.
func (s *Service) DeleteConversation(ctx context.Context, userID uuid.UUID, convID uuid.UUID) error {
	return s.queries.DeleteConversation(ctx, sqlc.DeleteConversationParams{
		ID:     pgtype.UUID{Bytes: convID, Valid: true},
		UserID: pgtype.UUID{Bytes: userID, Valid: true},
	})
}
