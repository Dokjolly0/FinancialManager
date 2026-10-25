package prompt

import "strings"

// Follow-up questions (plan.md section 32.6) reuse the analysis's stored
// system prompt, whose strongest rule is the report's list of headings. The
// rules below are added when a question is sent, never stored, so analyses
// made with older templates get them too.

type followUpText struct {
	SystemRules string `json:"system_rules"`
	Reminder    string `json:"reminder"`
}

const (
	followUpOpenTag  = "<follow_up_question>"
	followUpCloseTag = "</follow_up_question>"
)

// WithFollowUpRules is the system prompt of a follow-up turn: the stored
// one plus the rules for answering questions.
func WithFollowUpRules(system string, lang Lang) string {
	return strings.TrimSpace(system) + "\n\n" + loaded[normalizeLang(lang)].followUp.SystemRules
}

// FollowUpQuestion is a question as sent to the model: tagged, so it stands
// apart from the data and the report, and followed by a short reminder. A
// closing tag inside the question cannot end it early.
func FollowUpQuestion(question string, lang Lang) string {
	q := strings.ReplaceAll(strings.TrimSpace(question), "</follow_up_question", "‹/follow_up_question")
	return followUpOpenTag + "\n" + q + "\n" + followUpCloseTag + "\n\n" + loaded[normalizeLang(lang)].followUp.Reminder
}
