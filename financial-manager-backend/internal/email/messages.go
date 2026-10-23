package email

import (
	"fmt"
	"time"
)

// PasswordResetMessage is the email sent by "forgot password": link opens
// the reset page (dashboard, or the app through Android App Links).
func PasswordResetMessage(to, link string, validFor time.Duration) Message {
	return Message{
		To:      to,
		Subject: "Reimposta la password di FinancialManager",
		Body: fmt.Sprintf(`Ciao,

abbiamo ricevuto una richiesta di reimpostare la password del tuo account FinancialManager.

Apri questo link per sceglierne una nuova (vale %s e si può usare una volta sola):
%s

Se non hai fatto tu la richiesta, ignora questa email: la password resta quella attuale.

FinancialManager
`, italianDuration(validFor), link),
	}
}

// EmailVerificationMessage is sent at registration and on "resend
// verification".
func EmailVerificationMessage(to, link string, validFor time.Duration) Message {
	return Message{
		To:      to,
		Subject: "Conferma la tua email su FinancialManager",
		Body: fmt.Sprintf(`Ciao,

per confermare l'indirizzo email del tuo account FinancialManager apri questo link (vale %s):
%s

Se non hai creato tu un account, ignora questa email.

FinancialManager
`, italianDuration(validFor), link),
	}
}

// italianDuration renders the token lifetimes used here: whole hours
// ("1 ora", "24 ore") or minutes ("30 minuti").
func italianDuration(d time.Duration) string {
	if d >= time.Hour && d%time.Hour == 0 {
		if h := int(d / time.Hour); h != 1 {
			return fmt.Sprintf("%d ore", h)
		}
		return "1 ora"
	}
	if m := int(d / time.Minute); m != 1 {
		return fmt.Sprintf("%d minuti", m)
	}
	return "1 minuto"
}
