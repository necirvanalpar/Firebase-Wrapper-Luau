
# Firebase Realtime Database Wrapper for Roblox

A simple **Firebase Realtime Database REST API wrapper** for **Roblox**.  
Supports read, write, update, delete, and query operations.

---

### What is this?
This is a Firebase database wrapper for Roblox.  
It uses the Firebase REST API.  
You can read and write data easily.

### Features
- GET data  
- SET data  
- UPDATE data  
- PUSH new data  
- DELETE data  
- Query support:
  - orderBy  
  - equalTo  
  - startAt / endAt  
  - limitToFirst / limitToLast  

### Requirements
- Roblox Studio  
- HTTP Requests enabled  
- Firebase Realtime Database  

### Setup
1. Open Roblox Studio  
2. Go to **Game Settings → Security**  
3. Enable **HTTP Requests**  
4. Create a **ModuleScript**  
5. Paste `FirebaseRtdb.lua` code  

### Example
```lua
local Firebase = require(path.to.FirebaseRtdb)

local db = Firebase.new({
    BaseUrl = "https://your-project.firebaseio.com",
    AuthToken = "YOUR_TOKEN", -- optional
})

local ok, data = db:Get("users")
print(ok, data)
````

### Query Example

```lua
local ok, data = db:QueryByChild("users", "age", {
    equalTo = 10
})
print(data)
```

### Notes

* Use this in **ServerScript**
* Do not expose your token
* Firebase REST has limits

---

### Was ist das?

Das ist ein Firebase Datenbank Wrapper für Roblox.
Er benutzt die Firebase REST API.
Du kannst Daten einfach lesen und schreiben.

### Funktionen

* GET Daten lesen
* SET Daten schreiben
* UPDATE Daten ändern
* PUSH neue Daten
* DELETE Daten löschen
* Query Unterstützung:

  * orderBy
  * equalTo
  * startAt / endAt
  * limitToFirst / limitToLast

### Voraussetzungen

* Roblox Studio
* HTTP Requests aktiviert
* Firebase Realtime Database

### Installation

1. Roblox Studio öffnen
2. **Game Settings → Security**
3. **HTTP Requests** aktivieren
4. **ModuleScript** erstellen
5. Code einfügen

### Beispiel

```lua
local Firebase = require(path.to.FirebaseRtdb)

local db = Firebase.new({
    BaseUrl = "https://dein-projekt.firebaseio.com",
    AuthToken = "DEIN_TOKEN", -- optional
})

local ok, data = db:Get("users")
print(ok, data)
```

### Hinweise

* Nur im **ServerScript** benutzen
* Token nicht im Client speichern
* Firebase REST hat Limits

---

Copyright (c) 2026 Necrivan Alpar
