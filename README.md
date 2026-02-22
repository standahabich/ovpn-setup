# MikroTik OpenVPN Server Automation Script

## Overview
Tento skript automatizuje kompletní přípravu OpenVPN serveru na MikroTiku včetně:

- generování CA certifikátu
- generování serverového certifikátu
- generování klientských certifikátů
- exportu `.p12` záloh pro migraci
- exportu `.ovpn` konfiguračních souborů pro klienty
- vytvoření/úpravy IP poolu
- vytvoření/úpravy PPP profilu
- vytvoření/úpravy OVPN serveru
- vytvoření/úpravy PPP secretů
- průběh a výsledek generování směrován do logu

Skript je navržen tak, aby bylo **bezpečné ho spouštět opakovaně** — pokud něco existuje, nepřepisuje to, pouze doplní nebo opraví to, co je potřeba (např. certifikát, IP pool, profil).  
Je určený k tomu, aby:

- vytvořil vše potřebné
- vyexportoval zálohy
- vyexportoval klienty
- a poté už konfiguraci pouze opravoval

Díky tomu je možné server dále ručně upravit bez rizika, že skript změny přepíše.

---

## Naming konvence certifikátů
Skript používá jasnou a škálovatelnou strukturu názvů:

| Typ certifikátu | Formát Common Name |
|-----------------|--------------------|
| CA              | `ovpn_<serverName>_ca` |
| Server          | `ovpn_<serverName>_server` |
| Client          | `ovpn_<serverName>_client_<user>` |

Výhody:

- přehlednost
- snadné filtrování certifikátů
- možnost více OVPN serverů na jednom routeru
- čisté logování a správa

---

## Co skript dělá

### Certifikáty
- vytvoří CA certifikát (pokud neexistuje)
- vytvoří server certifikát (pokud neexistuje)
- vytvoří klientské certifikáty (pokud neexistují)
- podepíše je CA
- opraví názvy importovaných certifikátů
- ověří, že CA i server certifikát mají privátní klíč
- exportuje CA + server certifikát jako `.p12`
- exportuje klientské certy + klíče jako PEM

### OpenVPN server
- vytvoří nebo upraví IP pool
- vytvoří nebo upraví PPP profil
- vytvoří nebo upraví OVPN server (certificate, require-client-certificate, default-profile)
- vytvoří nebo upraví PPP secret pro každého klienta

### Export klientů .ovpn
Pro každého klienta skript:
- smaže všechny .opvn soubory z `/file`
- exportuje certifikát a klíč
- vytvoří `.ovpn` konfigurační soubor
- pojmenuje ho jako `<serverAddress>_<clientName>.ovpn`
- uklidí dočasné soubory

---

## Co skript nedělá
- nepřepisuje ruční nastavení OVPN serveru (port, cipher, push-routes, DNS, atd.)
- nepřegenerovává existující certifikáty
- nemaže existující klienty
- nemění nic, co není explicitně v jeho konfiguraci

Po prvním spuštění můžeš server libovolně doladit ručně a skript ti to už nikdy nepřepíše kromě důležitých věcí pro běh.

---

## Installation

Tento skript není balíček ani plugin — jde o čistý MikroTik RouterOS skript.  
Instalace spočívá pouze v jeho vložení do routeru.

### 1) Otevři WinBox / WebFig / SSH
Připoj se k routeru, kde bude OpenVPN server běžet.

### 2) Vytvoř nový skript
V WinBoxu:

```
System → Scripts → Add
```

### 3) Vlož obsah skriptu
Zkopíruj celý obsah `.rsc` skriptu do pole **Source**.

### 4) Uprav proměnné podle potřeby
V horní části skriptu uprav:

- `clientSecrets` – seznam klientů a jejich hesel
- `serverName` – název OVPN serveru a část common-name
- `serverAddress` – veřejná adresa serveru (IP nebo Domain)
- `clientPassphrase` – heslo pro export certifikátů
- `ipLocalAddress` – IP adresa serveru v OVPN síti
- `ipPoolRange` – rozsah IP adres pro klienty

### 5) Ulož skript
Klikni **OK**:

---

## Usage

Skript se spouští ručně — není určen pro automatické opakované spouštění.

### 1) Spusť skript

V WinBoxu:

```
System → Scripts → Run
```

### 2) Skript provede:

- vytvoření CA certifikátu (pokud neexistuje)
- vytvoření server certifikátu (pokud neexistuje)
- vytvoření klientských certifikátů
- export `.p12` záloh (CA + server cert)
- smazání všech `.ovpn` souborů z disku
- export `.ovpn` souborů pro klienty
- vytvoření/úpravu IP poolu
- vytvoření/úpravu PPP profilu
- vytvoření/úpravu OVPN serveru
- vytvoření/úpravu PPP secretů

### 3) Po dokončení najdeš soubory v `/file`

- `cert_export_*.p12` — zálohy certifikátů
- `<serverAddress>_<client>.ovpn` — klientské konfigurace

Tyto soubory si stáhni a bezpečně ulož.

---

## Re-running the script

Skript je navržen tak, aby bylo **bezpečné ho spouštět opakovaně**:

- existující certifikáty nepřepíše
- OVPN server nepřemaže
- pouze doplní nebo opraví to, co je potřeba (certifikát, pool, profil)

To znamená, že:

- můžeš skript spustit kdykoli znovu
- ruční úpravy OVPN serveru zůstanou zachovány
- skript slouží i jako bezpečný „refresh“ konfigurace

---

## Migration to a new router

1. Spusť skript na starém routeru  
2. Stáhni `.p12` soubory (CA + server cert)  
3. Stáhni `.ovpn` soubory pro klienty  
4. Na novém routeru importuj `.p12` `( /certificate/import file-name=...p12 passphrase=... )`
5. Vlož skript a spusť ho  
6. Skript automaticky opraví názvy certifikátů a nastaví server  
7. Ručně nastav port, TLS-auth, push-routes, atd.  

Klienti se připojí bez změny konfigurace.

---

## Requirements
- RouterOS 7.21+
- MikroTik s podporou OpenVPN serveru
- SSH/WinBox pro spuštění skriptu
- `.p12` exporty pro migraci (pokud přenášíš server)

---

## Notes
- Skript obsahuje ochranu proti paralelnímu běhu
- Je bezpečné ho spouštět opakovaně
- Naming konvence je navržena pro multi-server prostředí
- Exporty jsou ukládány do `/file`
