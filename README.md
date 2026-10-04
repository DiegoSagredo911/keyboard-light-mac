# ⌨️ Keyboard Light Mac

**Keyboard Light Mac** es una aplicación nativa para macOS diseñada para hacer que la retroiluminación del teclado de tu MacBook se ilumine y pulse al ritmo de la música que estás escuchando en tu Mac o de los sonidos capturados por el micrófono, con sensibilidad y parámetros completamente ajustables en tiempo real.

---

## 🌟 Características

- **🏎 Modo Velocímetro de Escritura (Typing Speedometer / WPM)**:
  - ¡El teclado reacciona en tiempo real a la velocidad con la que escribes con los dedos!
  - **⚡️ Destello por Tecla (Key Strobe)**: Cada tecla que pulsas genera un destello estroboscópico instantáneo. Cuanto más rápido tecleas, más rápido titila.
  - **🏎 Tacómetro Progresivo (WPM Rev)**: El brillo sube suavemente según tus palabras por minuto (WPM), como el cuentarrevoluciones o velocímetro de un auto deportivo.
  - **🔥 Turbo Strobe**: Al alcanzar alta velocidad de escritura (> 60 WPM), activa una ráfaga estroboscópica continua a toda velocidad.
- **🎵 Fuentes de Audio**:
  - **Música del MacBook (Audio del Sistema)**: Sonido interno de Spotify, Apple Music, YouTube, juegos, etc. vía *ScreenCaptureKit*.
  - **Micrófono del MacBook**: Reacciona a sonidos ambientales, voz o palmas vía *AVFoundation*.
- **🎚 Sensibilidad y Velocidad Objetivo Ajustable**:
  - Control continuo para calibrar tanto la música como el velocímetro (WPM objetivo de 30 a 150 WPM).
- **🥁 4 Modos de Reacción Musical**:
  1. **⚡️ Estroboscópico Ultra Rápido (Strobe / Discoteca)**: Destellos secos de 35-45 ms con corte inmediato a negro.
  2. **🥁 Ritmo (Beat / Bajo)**: Filtro biquad de frecuencias bajas con caída progresiva.
  3. **🌊 Volumen Fluido (RMS)**: Sigue suavemente la dinámica e intensidad global.
  4. **💫 Híbrido**: Luz ambiental continua + destellos brillantes en los beats.
- **📊 Vúmetro / Velocímetro y Monitor en Vivo**:
  - Muestra en tiempo real tanto el nivel de audio como tus palabras por minuto (`WPM`) y teclas por segundo (`tcl/s`).
- ** Integración Nativa en macOS**:
  - **Apagado Automático al Iniciar**: Si el teclado está encendido con brillo normal, el programa guarda ese valor y lo **apaga automáticamente a 0%** al abrirse, para que el espectáculo de luces empiece desde la oscuridad y responda con nitidez al ritmo de la música.
  - Funciona como una **aplicación de Barra de Menús** (`NSStatusItem` con icono `⌨️⚡️`), ocupando cero espacio en el Dock.
  - También incluye **modo Terminal (CLI)** para usuarios que prefieren la consola o scripts.
  - **Restauración automática**: Al cerrar o pausar la aplicación, el teclado regresa automáticamente a su brillo y configuración original de macOS.

---

## 🚀 Requisitos

- MacBook con teclado retroiluminado (Apple Silicon M1/M2/M3/M4 o Intel).
- macOS 13.0 (Ventura), macOS 14 (Sonoma), macOS 15 (Sequoia) o superior.
- Permisos del sistema:
  - **Micrófono**: Requerido si seleccionas la fuente de micrófono.
  - **Grabación de Pantalla y Audio del Sistema**: Requerido por macOS para la captura directa del audio interno de las aplicaciones mediante ScreenCaptureKit (*Ajustes del Sistema > Privacidad y Seguridad > Grabación de pantalla y audio del sistema*).

---

## 🛠 Compilación

El proyecto no requiere dependencias externas ni gestores de paquetes pesados. Se compila directamente con las herramientas nativas de Apple (`clang`):

```bash
./build.sh
```

o usando `make`:

```bash
make
```

Esto generará:
1. La aplicación nativa: `build/Keyboard Light.app`
2. El ejecutable de terminal: `build/keyboard-light`

### 📦 Crear Instalador para Distribuir

Para generar el archivo de instalación que puedes compartir con cualquier persona:

```bash
./create_installer.sh
```
o con `make`:
```bash
make installer
```

Esto genera automáticamente:
- **`build/Keyboard-Light-Mac-Installer.pkg`**: Instalador guiado oficial de macOS (doble clic y se instala solo en Aplicaciones).
- **`build/Keyboard-Light-Mac.zip`**: Paquete comprimido universal para compartir por internet o GitHub Releases.

---

## 📖 Modo de Uso

### 1. Interfaz Gráfica (Barra de Menús)

Para iniciar la aplicación gráfica:

```bash
open "build/Keyboard Light.app"
```

Verás aparecer el icono `⌨️⚡️` en la barra de menús superior derecha de tu Mac. Haz clic en él para abrir el panel de control:
- Activa o desactiva la sincronización con el botón **Iniciar / Detener**.
- Selecciona la **Fuente de audio** (*Micrófono* o *Audio del Sistema*).
- Elige el **Modo reactivo** (*Ritmo*, *Volumen Fluido* o *Híbrido*).
- Ajusta el control deslizante de **Sensibilidad**.
- Pulsa **Probar Pulso** para comprobar los destellos del teclado.

### 2. Modo Consola (Línea de Comandos)

Si prefieres ejecutarlo directamente desde la terminal:

```bash
# Modo micrófono con sensibilidad 1.8x
./build/keyboard-light --cli --source mic --sensitivity 1.8

# Modo música del sistema (Spotify, YouTube, etc.)
./build/keyboard-light --cli --source system --sensitivity 1.5 --mode 0
```

#### Opciones de la Línea de Comandos:

| Parámetro | Descripción | Valores |
|---|---|---|
| `--cli` | Activa el modo terminal sin interfaz gráfica | - |
| `--source` | Fuente de audio | `mic` (micrófono) o `system` (música interna del Mac) |
| `--sensitivity` | Multiplicador de sensibilidad | Número flotante (ej. `1.0`, `1.8`, `2.5`) |
| `--mode` | Modo de reacción musical | `0` = Ritmo/Bajo, `1` = Volumen Fluido, `2` = Híbrido |
| `--help` | Muestra la ayuda de comandos | - |

Para detener el modo terminal pulsa `Ctrl + C`. El teclado restaurará automáticamente su nivel de brillo previo.

---

## 🎧 Música Recomendada para Probar el Efecto Strobe

Para sacarle el máximo partido a las luces estroboscópicas, lo ideal es música con **bombos secos (kicks)**, **transientes marcados** y **ritmo constante**:

1. **EDM / Festival House / Dance**:
   - Martin Garrix – *Animals* (el drop tiene bombos secos ideales para el parpadeo).
   - Fisher – *Losing It* (bombo constante de club a 125 BPM).
   - David Guetta & Bebe Rexha – *I'm Good (Blue)*.
2. **Techno / Hardstyle / Psytrance**:
   - Charlotte de Witte – *Doppler* / *Age of Love*.
   - Armin van Buuren – *Great Spirit* (Psytrance con ráfagas de 138 BPM).
3. **Phonk / Drift Phonk** (¡El mejor género para probar!):
   - Kordhell – *Murder In My Mind* (bajos 808 ultra distorsionados y cajas rápidas).
   - DVRST – *Close Eyes*.
   - Hensonn – *Flare*.
4. **Hip-Hop / Trap**:
   - Travis Scott – *SICKO MODE* / *goosebumps* (kicks 808 profundos).
5. **Rock Clásico / Pop con Batería Marcada**:
   - AC/DC – *Back in Black* (golpes secos de batería).
   - Michael Jackson – *Billie Jean* (el patrón bombo-caja más icónico).

> 💡 **Consejo de calibración rápida**: Sube el volumen de tu Mac al 60-80% o ajusta la **Sensibilidad** a `1.8x` - `2.2x` para que cada golpe sobrepase el umbral de disparo.

---

```text
├── src/
│   ├── KeyboardController.h/.m   # Control del hardware del teclado via CoreBrightness
│   ├── AudioAnalyzer.h/.m        # DSP: Filtro paso bajo, detector de ritmo/beat y envolvente
│   ├── AudioCaptureEngine.h/.m   # Captura dual: ScreenCaptureKit (sistema) y AVAudioEngine (micro)
│   ├── AppController.h/.m        # Interfaz de usuario para la barra de menús de macOS
│   └── main.m                    # Punto de entrada (soporte AppKit y CLI)
├── Info.plist                    # Metadatos del bundle y descripciones de permisos
├── Makefile                      # Reglas de compilación y empaquetado
├── build.sh                      # Script de compilación rápida
└── README.md                     # Documentación completa
```

---

## 👨‍💻 Autor

Desarrollado con pasión por [Diego Sagredo](https://github.com/diegosagredo911).

---

## 📄 Licencia

Este proyecto está bajo la licencia **GNU General Public License v3.0 (GPL-3.0)**.

- ✅ **Uso libre**: Eres libre de usar, ejecutar y compartir este software sin restricciones ni coste alguno.
- 🔓 **Modificaciones públicas obligatorias (*Copyleft*)**: Cualquier modificación, mejora o software derivado de este proyecto **debe ser obligatoriamente público y de código abierto** bajo los mismos términos de esta licencia GPL-3.0.

Consulta el archivo [**`LICENSE`**] para ver el texto legal completo.
