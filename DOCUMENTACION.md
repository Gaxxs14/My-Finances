# Documentación Técnica del Sistema - My Finances (v1.0 Producción)

Este documento contiene la especificación técnica completa del funcionamiento, arquitectura, modelo de seguridad, esquemas de datos y manual de mantenimiento del sistema **My Finances**. Está diseñado como referencia definitiva para el uso actual y para guiarse en futuras expansiones y actualizaciones.

---

## 1. Visión General del Sistema

* **Nombre de la Aplicación:** My Finances
* **Tipo de Aplicación:** Aplicación Móvil Híbrida de Finanzas Personales Multi-moneda + Bóveda de Contraseñas Cifrada.
* **Filosofía de Arquitectura:** **Local-First Zero-Knowledge** (El dispositivo funciona al 100% offline con base de datos cifrada y sincroniza opcionalmente en la nube de forma transparente).
* **Servidor Backend:** C# ASP.NET Core Web API en Render (`https://my-finances-9kah.onrender.com`).
* **Compilado Entregado:** `C:\Users\ggallardo\Desktop\MyFinances.apk` (Android Release, 72.3 MB).

---

## 2. Stack Tecnológico y Componentes

### A. Frontend (Aplicación Móvil - `/frontend`)
* **Framework:** Flutter 3.x (Lenguaje Dart).
* **Gestión de Estado:** `flutter_riverpod` (Providers globales e inmutables).
* **Base de Datos Local Cifrada:** `sqflite_sqlcipher` (Base de datos SQLite cifrada mediante AES-256).
* **Almacenamiento Seguro Nivel Hardware:** `flutter_secure_storage` (Android KeyStore / iOS Keychain).
* **Cliente HTTP:** `dio` (Con interceptores de autenticación JWT y timeout extendido de 30s).
* **Hardware Interfacing:**
  * `nfc_manager` (Lectura y detección de tarjetas físicas NFC).
  * `local_auth` (Autenticación por huella dactilar / FaceID).
  * `image_picker` (Cámara y Galería para foto de perfil).

### B. Backend (Servidor Web API - `/backend`)
* **Lenguaje y Framework:** C# ASP.NET Core 9 Web API (`backend/MyFinances.API`).
* **ORM:** Entity Framework Core (EF Core 9).
* **Base de Datos en la Nube:** PostgreSQL Alojado en Render Cloud.
* **Autenticación:** JWT Bearer Token (`Microsoft.AspNetCore.Authentication.JwtBearer`).
* **Cifrado de Contraseñas Servidor:** BCrypt.Net.

---

## 3. Modelo de Seguridad Zero-Knowledge

1. **Cifrado en Reposo (Teléfono):**
   - El archivo `my_finances_secure.db` está cifrado físicamente con **SQLCipher (AES-256)**.
   - La clave maestra de cifrado de la base de datos se deriva de la combinación del usuario y contraseña maestra del usuario (mediante PBKDF2/SHA-256).
   - Ningún archivo plano ni contraseña se guarda sin cifrar.

2. **Cifrado en Tránsito (Red):**
   - Toda la comunicación con `https://my-finances-9kah.onrender.com` viaja por canales cifrados TLS/HTTPS.
   - El Token JWT emite una validez de 7 días y se re-autentica automáticamente en segundo plano.

3. **Bóveda de Credenciales:**
   - Las contraseñas del módulo "Bóveda" se cifran con AES-256 en el teléfono **antes** de sincronizarse con la nube. El servidor en Render solo almacena blobs cifrados indescifrables.

---

## 4. Esquema de Base de Datos Local (SQLite SQLCipher v3)

### Tabla `accounts` (Cuentas y Tarjetas)
```sql
CREATE TABLE accounts (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  type TEXT NOT NULL,       -- 'bank', 'card', 'cash', 'savings'
  balance REAL NOT NULL DEFAULT 0.0, -- Guardado en Moneda Base USD
  currency TEXT NOT NULL DEFAULT 'USD',
  color TEXT,               -- Código Hexadecimal (ej: '#1E40AF')
  is_active INTEGER NOT NULL DEFAULT 1
);
```

### Tabla `transactions` (Ingresos y Gastos)
```sql
CREATE TABLE transactions (
  id TEXT PRIMARY KEY,
  account_id TEXT NOT NULL,
  type TEXT NOT NULL,       -- 'income', 'expense', 'savings'
  amount REAL NOT NULL,     -- Guardado en Moneda Base USD
  currency TEXT NOT NULL DEFAULT 'VES', -- Moneda original del registro
  category TEXT NOT NULL,
  description TEXT,
  date TEXT NOT NULL,       -- Cadena de texto ISO 8601
  is_synced INTEGER NOT NULL DEFAULT 0,
  FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE
);
```

### Tabla `password_vault` (Bóveda de Credenciales Cifrada)
```sql
CREATE TABLE password_vault (
  id TEXT PRIMARY KEY,
  service_name TEXT NOT NULL,
  username TEXT NOT NULL,
  encrypted_password TEXT NOT NULL,
  website_url TEXT,
  encrypted_notes TEXT,
  updated_at TEXT NOT NULL
);
```

### Tabla `savings_goals` (Metas de Ahorro)
```sql
CREATE TABLE savings_goals (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  target_amount REAL NOT NULL,
  current_amount REAL NOT NULL DEFAULT 0.0,
  target_date TEXT,
  icon_name TEXT,
  color_hex TEXT,
  is_completed INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL
);
```

### Tabla `recurring_payments` (Pagos Fijos y Suscripciones)
```sql
CREATE TABLE recurring_payments (
  id TEXT PRIMARY KEY,
  account_id TEXT,
  name TEXT NOT NULL,
  amount REAL NOT NULL,
  currency TEXT NOT NULL DEFAULT 'VES',
  category TEXT NOT NULL,
  due_day INTEGER NOT NULL,
  icon_name TEXT,
  is_active INTEGER NOT NULL DEFAULT 1,
  last_paid_month TEXT
);
```

---

## 5. Lógica de Ingeniería Financiera y Conversión

1. **Almacenamiento Base Unificado:**
   - Todos los saldos de cuentas y importes de transacciones se calculan e insertan internamente en la base de datos local en **Base USD**.
2. **Conversión en Tiempo Real (Bs. VES):**
   - Cuando la app muestra montos en Bolívares (modo por defecto), invoca `_formatAmount(amountInUsd, bcvRate)` que calcula: `amountInUsd * bcvRate`.
3. **Registro Multi-Moneda:**
   - Al registrar una transacción en **Bs. VES**, el sistema calcula `montoUsd = montoIngresado / bcvRate` antes de insertar en la base de datos.
   - De esta forma, registrar 150 Bs. a una tasa de 764.35 se guarda como `0.1962 USD` y se renderiza exactamente como **`150,00 Bs.`**.
4. **Reversión de Saldos al Eliminar:**
   - Al tocar el ícono de papelera 🗑️ en un movimiento, la función `deleteTransaction` ejecuta una transacción atómica que invierte el impacto financiero en la tarjeta correspondiente (`balance += amount` para gastos, `balance -= amount` para ingresos) y elimina la fila de SQLite.

---

## 6. Endpoints del Backend C# (`https://my-finances-9kah.onrender.com`)

| Método | Endpoint | Descripción | DTO / Payload Esperado |
|---|---|---|---|
| `POST` | `/api/auth/register` | Registro inicial de usuario en la nube | `{"username": "...", "password": "..."}` |
| `POST` | `/api/auth/login` | Inicio de sesión para obtener Token JWT | `{"username": "...", "password": "..."}` |
| `POST` | `/api/sync/accounts` | Sincronización bidireccional de cuentas | `[{"id": "...", "name": "...", "type": "...", "balance": 0.0, "currency": "USD", "isActive": true}]` |
| `POST` | `/api/sync/transactions` | Sincronización bidireccional de transacciones | `[{"id": "...", "accountId": "...", "type": "...", "amount": 0.0, "category": "...", "description": "...", "date": "..."}]` |
| `POST` | `/api/sync/credentials` | Sincronización de credenciales cifradas | `[{"id": "...", "serviceName": "...", "username": "...", "encryptedPassword": "...", ...}]` |
| `POST` | `/api/sync/reset` | Borrado completo de datos del usuario en Render | Requiere Header `Authorization: Bearer <TokenJWT>` |

---

## 7. Manual para Futuras Actualizaciones y Mantenimiento

### A. ¿Cómo actualizar la aplicación Flutter?
1. Abre la terminal en la carpeta `/frontend`.
2. Para probar en modo de desarrollo:
   ```bash
   flutter run
   ```
3. Para compilar una nueva versión del APK de producción:
   ```bash
   flutter build apk --release
   ```
4. El APK resultante se generará en:
   `frontend/build/app/outputs/flutter-apk/app-release.apk`

### B. ¿Cómo desplegar cambios en el Backend C# en Render?
1. El proyecto en C# se ubica en `/backend/MyFinances.API`.
2. Al realizar cambios en C# y subir los commits a la rama principal de tu repositorio en GitHub:
   ```bash
   git add .
   git commit -m "Actualización del backend"
   git push origin main
   ```
3. Render detectará el push y recompilará automáticamente el contenedor Docker en vivo.

### C. Restablecimiento total de prueba:
Para limpiar por completo cualquier dato de prueba:
1. En la app móvil: Ve a **Perfil** -> **Cerrar Sesión y Restablecer Dispositivo**.
2. La app enviará una llamada a `/api/sync/reset` en Render para borrar el servidor, eliminará el archivo `my_finances_secure.db` local del teléfono y dejará todo listo para un inicio limpio.

---
*Documentación generada y verificada para la versión 1.0 de Producción.*
