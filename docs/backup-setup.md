# Configuración de Google Drive Backup para Pockt

Esta guía describe paso a paso cómo configurar el proyecto en Google Cloud para habilitar el respaldo cifrado en Google Drive con la credencial OAuth de Android.

> **Importante:** Todos los identificadores, correos y huellas en este documento son marcadores de posición (`<...>`). No introduzcas credenciales ni datos reales en el repositorio.

---

## Prerrequisitos

- Cuenta de Google para administración en Google Cloud Console.
- Java Development Kit (JDK) instalado con la herramienta de terminal `keytool`.
- Keystore de release de la aplicación (o debug para pruebas locales).

---

## Paso 1: Crear proyecto en Google Cloud Console

1. Accedé a [Google Cloud Console](https://console.cloud.google.com/).
2. En la barra superior, hacé clic en el selector de proyectos y seleccioná **Nuevo proyecto**.
3. Asignale un nombre representativo (por ejemplo, `Pockt`) y confirmá con **Crear**.
4. Asegurate de tener seleccionado el proyecto recién creado en el selector superior.

---

## Paso 2: Habilitar Google Drive API

1. En el menú lateral, navegá a **APIs y servicios** → **Biblioteca** (Library).
2. En la barra de búsqueda, ingresá `Google Drive API`.
3. Seleccioná el resultado correspondiente y hacé clic en **Habilitar** (Enable).

---

## Paso 3: Configurar la pantalla de consentimiento OAuth

1. En el menú lateral, ingresá a **APIs y servicios** → **Pantalla de consentimiento de OAuth**.
2. Seleccioná **Tipo de usuario**: `Externo` (External) y hacé clic en **Crear**.
3. Completá la información básica de la aplicación:
   - **Nombre de la aplicación:** `Pockt`
   - **Correo de asistencia del usuario:** `<tu-correo@gmail.com>`
   - **Datos de contacto del desarrollador:** `<tu-correo@gmail.com>`
4. En la sección **Permisos** (Scopes):
   - Hacé clic en **Agregar o quitar permisos**.
   - Buscá y seleccioná el scope:
     ```text
     https://www.googleapis.com/auth/drive.file
     ```
     *(Ver, crear y editar solo los archivos que la app ha creado en Google Drive).*
   - Hacé clic en **Actualizar** y luego en **Guardar y continuar**.
5. En la sección **Usuarios de prueba** (Test users):
   - El proyecto quedará en estado **En pruebas** (Testing).
   - Hacé clic en **+ Agregar usuarios** e ingresá la dirección de correo con la que iniciarás sesión en el dispositivo:
     `<tu-correo@gmail.com>`
   - Hacé clic en **Guardar y continuar**.

---

## Paso 4: Obtener la huella digital SHA-1 del Keystore

Para autorizar la aplicación de Android ante Google OAuth, se requiere la huella SHA-1 del certificado de firma.

### Para el keystore de Release (producción):
Ejecutá el siguiente comando en la terminal:

```bash
keytool -list -v -keystore <ruta-a-tu-keystore.jks> -alias <alias-de-tu-clave>
```

Ingresá la contraseña del keystore cuando sea solicitada.

### Para el keystore de Debug (pruebas locales):
Si deseás probar en un entorno de desarrollo local antes de compilar en release:

```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

En la salida del comando, buscá la línea correspondiente a la huella SHA-1:

```text
Certificate fingerprints:
     SHA1: <SHA1_FINGERPRINT>
```

Copiá el valor de `<SHA1_FINGERPRINT>` (ejemplo de formato: `AA:BB:CC:DD:EE:...`).

---

## Paso 5: Crear credencial OAuth de Android

1. En Google Cloud Console, navegá a **APIs y servicios** → **Credenciales**.
2. Hacé clic en **+ Crear credenciales** y seleccioná **ID de cliente de OAuth**.
3. En **Tipo de aplicación**, seleccioná **Android**.
4. Completá los campos:
   - **Nombre:** `Pockt Android Client` (o el nombre descriptivo que prefieras).
   - **Nombre del paquete:** `io.github.pacotez12.pockt`
   - **Huella digital del certificado SHA-1:** Pegá la huella obtenida en el Paso 4 (`<SHA1_FINGERPRINT>`).
5. Hacé clic en **Crear**.

Google Cloud creará el cliente OAuth (con un ID con formato `<CLIENT_ID>.apps.googleusercontent.com`).

> **Nota para Android:** No es necesario descargar ningún archivo `google-services.json` para Google Sign-In con este flujo. Google Play Services en el dispositivo Android coteja automáticamente el nombre de paquete `io.github.pacotez12.pockt` y la firma de la app con el cliente registrado en Google Cloud.

---

## Paso 6: Verificación y uso en la app

1. Instalá la app compilada con el keystore correspondiente en tu dispositivo.
2. Ingresá en **Ajustes** → **Backup** en Pockt.
3. Al presionar **Respaldar ahora** o conectar cuenta de Google:
   - Se abrirá el selector de cuentas de Google Play Services.
   - Seleccioná la cuenta autorizada como usuario de prueba (`<tu-correo@gmail.com>`).
   - Aceptá el consentimiento para gestionar archivos creados por la aplicación.
4. El respaldo se guardará en Google Drive dentro de una carpeta llamada `Pockt · Backups`.
