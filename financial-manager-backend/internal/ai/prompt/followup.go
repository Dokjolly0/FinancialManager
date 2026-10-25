package prompt

import "strings"

// Follow-up questions (plan.md section 32.6) reuse the analysis's stored
// system prompt, whose strongest rule is the report's list of headings. The
// rules below are added when a question is sent, never stored, so analyses
// made with older templates get them too.
//
// Chats (PresetChat, plan.md section 34) have no report: their system
// prompt already describes the conversation, and every question, the first
// included, is tagged the same way.

type followUpText struct {
	SystemRules  string `json:"system_rules"`
	Reminder     string `json:"reminder"`
	ChatReminder string `json:"chat_reminder"`
}

// questionTag is the tag a question is wrapped in.
func questionTag(preset string) string {
	if preset == PresetChat {
		return "question"
	}
	return "follow_up_question"
}

// WithFollowUpRules is the system prompt of a follow-up turn: the stored
// one plus the rules for answering questions. A chat's prompt is already
// about questions and is kept as is.
func WithFollowUpRules(system string, lang Lang, preset string) string {
	if preset == PresetChat {
		return system
	}
	return strings.TrimSpace(system) + "\n\n" + loaded[normalizeLang(lang)].followUp.SystemRules
}

// FollowUpQuestion is a question as sent to the model: tagged, so it stands
// apart from the data and the earlier answers, and followed by a short
// reminder. A closing tag inside the question cannot end it early.
func FollowUpQuestion(question string, lang Lang, preset string) string {
	tag := questionTag(preset)
	text := loaded[normalizeLang(lang)].followUp
	reminder := text.Reminder
	if preset == PresetChat {
		reminder = text.ChatReminder
	}
	q := strings.ReplaceAll(strings.TrimSpace(question), "</"+tag, "‹/"+tag)
	return "<" + tag + ">\n" + q + "\n</" + tag + ">\n\n" + reminder
}

// ChatUserMessage is a chat's first message: the data, the transactions
// attached to the question if any (see RenderMatches), then the question,
// tagged as every later one.
func ChatUserMessage(question, dataBlock, attachment string, lang Lang) string {
	return dataBlock + "\n\n" + WithAttachment(attachment, FollowUpQuestion(question, lang, PresetChat))
}

// WithAttachment puts a question's attached data before the wrapped
// question; the question alone when there is none.
func WithAttachment(attachment, wrappedQuestion string) string {
	if attachment == "" {
		return wrappedQuestion
	}
	return attachment + "\n\n" + wrappedQuestion
}

// ChatQuestion returns the question of a chat's first message, as typed;
// "" when the message has none.
func ChatQuestion(firstMessage string) string {
	const open, close = "\n\n<question>\n", "\n</question>"
	start := strings.LastIndex(firstMessage, open)
	if start < 0 {
		return ""
	}
	rest := firstMessage[start+len(open):]
	end := strings.Index(rest, close)
	if end < 0 {
		return ""
	}
	return strings.ReplaceAll(rest[:end], "‹/question", "</question")
}
