# Documentación del Sistema de Finanzas Personales y Gestor de Contraseñas Seguras

Este documento detalla la arquitectura recomendada, tecnologías, modelo de seguridad y estrategias de despliegue gratuito en la nube para el desarrollo del sistema robusto de finanzas personales.

---

## 1. Arquitectura Tecnológica Recomendada

El sistema se organizará físicamente como un monorepo para facilitar el desarrollo conjunto en el mismo espacio de trabajo, pero manteniendo repositorios de Git independientes.

### Resumen del Stack Tecnológico
*   **Aplicación Móvil (Frontend):** Flutter (Dart) - Ubicado en `/frontend` (Generará el APK para Android).
*   **Servidor de Aplicaciones (Backend API):** ASP.NET Core (C#) - Ubicado en `/backend` (Administrará la lógica central, validaciones y sincronización).
*   **Base de Datos en la Nube:** PostgreSQL (Alojado en Neon.tech).
*   **Base de Datos Local (Modo Offline y Seguro):** SQLite con SQLCipher (cifrada con AES-256 en el celular).

```
[ App Flutter (/frontend) ] 
       │ (Sincronización HTTPS cifrada con SSL Pinning y tokens JWT)
       ▼
[ API C# (/backend) ] 
       │ (Conexión segura SSL)
       ▼
[ Base de Datos PostgreSQL (Neon Cloud) ]
```

---

## 2. Modelo de Seguridad Extrema (Cero Conocimiento)

Dado que la aplicación almacenará **contraseñas y registros financieros reales**, el sistema debe implementarse bajo el principio de **Zero-Knowledge** (el servidor de la nube nunca debe conocer tus contraseñas en texto plano).

### A. Cifrado en Reposo (Local y Nube)
1.  **En el celular:**
    *   Toda información guardada localmente (transacciones, saldos, contraseñas de cuentas bancarias) se almacenará en una base de datos **SQLite cifrada mediante SQLCipher**.
    *   La clave de cifrado de la base de datos se guardará en el almacenamiento seguro del hardware del celular (`Keystore` en Android) usando el paquete `flutter_secure_storage`.
2.  **En la base de datos de la nube (Postgres):**
    *   Los campos sensibles como contraseñas del gestor de cuentas se enviarán al servidor **ya encriptados con AES-256 desde el celular**. La llave de desencriptación es una "Clave Maestra" derivada de tu contraseña de usuario, la cual **nunca** se envía al servidor.
    *   Si la base de datos en la nube es comprometida o hackeada, el atacante solo verá datos cifrados indescifrables.

### B. Cifrado en Tránsito
*   **HTTPS/TLS:** Toda la comunicación entre Flutter y el backend C# viajará sobre canales cifrados TLS.
*   **SSL Pinning:** Se configurará la aplicación móvil para que solo confíe en el certificado SSL de tu servidor específico en la nube, evitando ataques de intermediarios (Man-in-the-Middle) en redes Wi-Fi públicas.

### C. Autenticación y Autorización
*   **Inicio de Sesión:** Autenticación de doble factor simulada o integración con **Autenticación Biométrica** (Huella/Cara) usando las APIs nativas del dispositivo a través de `local_auth`.
*   **Tokens JWT (JSON Web Tokens):** Una vez que inicias sesión, el backend C# emite un token seguro de corta duración firmado digitalmente para autorizar las peticiones de sincronización.
*   **Contraseñas de la cuenta:** El hash de tu contraseña de acceso al sistema se guardará en la base de datos utilizando el algoritmo **BCrypt** con un factor de trabajo alto para evitar ataques de fuerza bruta.

---

## 3. Infraestructura y Hosting Cloud (100% Gratuito)

Para levantar este sistema sin costo alguno, utilizaremos proveedores con capas gratuitas permanentes y robustas.

### A. Base de Datos en la Nube: Neon.tech
*   **Servicio:** PostgreSQL Serverless.
*   **Costo:** Gratis para 1 proyecto (hasta 0.5 GB de almacenamiento).
*   **Seguridad:** Conexión segura obligatoria, backups automáticos de los últimos 7 días.

### B. Servidor API en C#: Koyeb o Render
*   **Servicio:** Alojamiento de contenedores Docker.
*   **Costo:** Capa gratuita permanente para 1 micro-instancia.
*   **Detalle:** El backend en C# se empaquetará dentro de un contenedor Docker ligero. Koyeb/Render detectarán el código en GitHub y compilarán automáticamente el contenedor.
*   *Nota de Render:* En la capa gratuita, el servidor se "duerme" tras 15 minutos sin peticiones. Tardará unos 30 segundos en reactivarse con la primera petición.

### C. Repositorio y Despliegue Automático (CI/CD): GitHub
*   **Servicio:** Control de versiones Git.
*   **Flujo:** Al hacer `git push` a la rama `main` en GitHub, Koyeb/Render automáticamente descargarán el código, pasarán las pruebas y publicarán los cambios en el servidor en vivo sin intervención manual.

---

## 4. Estructura y Organización del Código

Para mantener un proyecto robusto que no se vuelva caótico al crecer, se aplicará **Arquitectura Limpia (Clean Architecture)**.

### Estructura General del Workspace
```text
My-Finances/
├── DOCUMENTACION.md             # Este archivo
├── frontend/                   # Proyecto Flutter
│   ├── lib/
│   ├── pubspec.yaml
│   └── ...
└── backend/                    # Proyecto C# .NET API
    ├── MyFinances.API/
    ├── MyFinances.Domain/
    ├── MyFinances.Infrastructure/
    └── ...
```

### Estructura de la Aplicación Flutter (`/frontend`)
```
frontend/lib/
├── core/                        # Configuración e infraestructura compartida
│   ├── network/                 # Cliente HTTP (Dio), interceptores de seguridad
│   ├── security/                # Utilidades de encriptación AES y llavero seguro
│   ├── theme/                   # Diseño visual, colores y tipografía premium
│   └── utils/                   # Clases de ayuda y validaciones
│
├── features/                    # Módulos independientes de la aplicación
│   ├── auth/                    # Login, Registro, Biometría
│   │   ├── data/                # Modelos y fuentes de datos (remoto/local)
│   │   ├── domain/              # Lógica de negocio pura (Casos de Uso)
│   │   └── presentation/        # Pantallas, widgets y controladores (UI)
│   │
│   ├── dashboard/               # Resumen financiero, gráficos
│   ├── transactions/            # Registro de gastos, ahorros e ingresos
│   └── password_manager/        # Gestor de contraseñas de cuentas encriptado
│
└── main.dart                    # Punto de entrada de la aplicación
```

### Estructura del Backend C# (`/backend`)
```
backend/
├── MyFinances.API/              # Controladores HTTP, Middlewares de seguridad, Configuración JWT
├── MyFinances.Application/      # Lógica de negocio, DTOs, interfaces de servicio
├── MyFinances.Domain/           # Entidades financieras puras (Transaction, User, Account)
└── MyFinances.Infrastructure/   # Conexión a Base de Datos (EF Core, PostgreSQL), Encriptación
```

---

## 5. Estrategia de Control de Versiones (Git y GitHub)

Dado que cuentas con repositorios creados en tu cuenta de GitHub, seguiremos las siguientes directrices:

1.  **Ramas Principales:**
    *   `main`: Contiene el código de producción listo para compilar la APK final y desplegar el backend estable en producción.
    *   `develop`: Rama de integración donde se consolidan las nuevas funciones antes de ir a producción.
2.  **Ramas de Características (`feature/`):**
    *   Cada nueva funcionalidad (ej: `feature/biometric-auth`, `feature/database-setup`) se desarrolla en una rama separada nacida de `develop` y se une mediante un *Pull Request* revisado.
3.  **Seguridad en Git:**
    *   Queda estrictamente prohibido subir claves de API, contraseñas de bases de datos o llaves de firma al repositorio de GitHub. Todos estos datos se manejarán como variables de entorno (`.env` o Secrets en la plataforma de la nube).

---

## 6. Siguientes Pasos Recomendados

1.  **Crear las subcarpetas `/frontend` y `/backend`**.
2.  **Inicialización de Flutter:** Crear el proyecto móvil en `/frontend`.
3.  **Enlazar Repositorio Local con GitHub:** Clonar o agregar las direcciones remotas correspondientes en cada subcarpeta.
4.  **Configuración de Dependencias:** Modificar el `pubspec.yaml` de la app móvil.
