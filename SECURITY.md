# Sicurezza

## Distribuzione e integrità

`PC Facile.bat` scarica sempre l'ultima versione di `setup-pc.ps1` da `main` e
ne verifica lo **SHA256** contro `setup-pc.ps1.sha256` pubblicato accanto allo
script: se l'impronta non combacia (download corrotto o troncato) **oppure non
si riesce a scaricarla**, il file viene scartato e, in mancanza di un download
verificato, si usa la copia locale sulla chiavetta. La copia sulla chiavetta
viene aggiornata solo con un download verificato. Su Mac `PC Facile.command`
applica la stessa regola a `setup-mac.sh` con `setup-mac.sh.sha256`. L'hash rileva le corruzioni ma, essendo
pubblicato nello stesso repository, **non sostituisce una firma digitale**.

Quando è disponibile un certificato aziendale di code signing, firmare
`setup-pc.ps1` con Authenticode e distribuire il certificato pubblico sui PC del
negozio. La chiave privata non deve mai finire nel repository o nei workflow
senza un archivio segreti dedicato.

## Dati sensibili

La scheda di consegna sul Desktop (`Scheda-Consegna-Cliente.pdf`, o `.html` di
ripiego) contiene **intenzionalmente** credenziali in chiaro e la chiave di ripristino
BitLocker: servono al flusso interno del negozio e restano con il PC del
cliente. Il riepilogo tecnico e i log in `C:\ProgramData\PCFacile\log` non
contengono password né recovery key. Vanno consegnati e conservati secondo le procedure aziendali, mai
allegati a issue, commit o log pubblici.

## Segnalazioni

Per problemi di sicurezza, aprire una **segnalazione privata** su GitHub
(Security advisory) anziché una issue pubblica.
