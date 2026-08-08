# Teil II — Channels & Connectivity {.unnumbered}

Teil II befasst sich damit, wie Anrufe in Asterisk hinein- und wieder herausgelangen. Wir beginnen mit dem Entwurf des VoIP-Netzwerks um Asterisk herum — Codecs, Bandbreite und NAT — und untersuchen dann eingehend SIP und dessen moderne PJSIP-Implementierung, da PJSIP der einzige SIP-Channel in Asterisk 22 ist.

Von dort aus fügen wir die Verbindungen hinzu, die ein echter Einsatz erfordert: Browser-Telefonie mit WebRTC, Trunks und DIDs zur Anbindung an das PSTN und Ihre Provider sowie die klassischen analogen, digitalen (TDM) und IAX2-Channels, denen Sie in der Praxis noch begegnen könnten. Am Ende werden Sie in der Lage sein, Asterisk gleichermaßen mit Telefonen, Browsern, Carriern und älteren Geräten zu verbinden.
