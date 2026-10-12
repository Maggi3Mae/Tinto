<p align="center">
  <img src="docs/icon.svg" width="128" alt="Ícono de Tinto">
</p>

<h1 align="center">Tinto</h1>

<p align="center">
  Mantén tu Mac despierto, incluso con la tapa cerrada.<br>
  Una pequeña app de barra de menú para macOS, gratis y de código abierto.
</p>

<p align="center">
  <a href="https://github.com/Maggi3Mae/tinto/releases/latest"><b>Descargar</b></a> ·
  <a href="https://maggi3mae.github.io/tinto/">Página</a> ·
  <a href="README.md">English</a>
</p>

---

En Colombia, un *tinto* es un café negro pequeño, el que te mantiene despierto.

## Funciones

- **Un clic** en el grano de café de la barra de menú para activarlo o desactivarlo.
- **Temporizadores**: 15 min, 30 min, 1 h, 2 h, 4 h, 8 h, un tiempo personalizado o hasta una hora concreta.
- **Modo tapa cerrada**: cierra tu MacBook y sigue trabajando en una pantalla externa, **sin cargador, teclado ni mouse externos**.
- **Sesiones estables**: si el cable de la pantalla se desconecta un momento, Tinto sigue activo. No hay que abrir nada ni reacomodar.
- **Seguro de batería** (opcional): termina la sesión si la batería baja del nivel que elijas.
- **Simular actividad** (opcional): mantiene tu estado como *Disponible* en apps como Teams o Slack mientras no estás.
- Tiempo restante junto al ícono, apertura al iniciar sesión, español e inglés.
- Sin cuenta, sin App Store, sin rastreo.

## Instalación

Requiere **macOS 14 Sonoma o posterior** · Apple Silicon e Intel.

1. Descarga el último **Tinto-x.y.z.dmg** desde [Releases](https://github.com/Maggi3Mae/tinto/releases/latest).
2. Ábrelo y arrastra **Tinto** a **Aplicaciones**.
3. Abre Tinto. La primera vez macOS lo bloqueará porque no está firmado con un certificado pago de Apple:
   haz clic en **Listo**, ve a **Ajustes del Sistema → Privacidad y seguridad**, baja hasta el final y pulsa **Abrir de todas formas**.

   <details>
   <summary>¿Prefieres la Terminal?</summary>

   ```bash
   xattr -dr com.apple.quarantine /Applications/Tinto.app
   ```
   </details>

## Uso

| Acción | Qué hace |
| --- | --- |
| **Clic** en el grano | Activar (sin límite) / desactivar |
| **Clic derecho** (o ⌥ + clic) | Temporizadores, ajustes, desinstalar |

El grano está **relleno** cuando Tinto está activo y en **contorno** cuando está apagado.

### Sobre el modo tapa cerrada

macOS solo deja al Mac despierto con la tapa cerrada si está cargando. Tinto quita ese límite con el ajuste del propio sistema `pmset disablesleep`.
La primera vez que lo uses, Tinto te pedirá la contraseña **una sola vez** para crear una regla que le permite ejecutar exactamente dos comandos, `pmset -a disablesleep 1` y `pmset -a disablesleep 0`, y nada más. El reposo normal vuelve en cuanto termina la sesión o cierras Tinto.

> **Ojo:** con el modo tapa cerrada activo, el Mac no se duerme ni dentro de una maleta. Desactiva Tinto antes de guardarlo para que no se caliente.

### Sobre simular actividad

Algunas apps (Teams, Slack…) te marcan como *Ausente* tras unos minutos sin teclado ni mouse, aunque el Mac esté despierto. Con **Simular actividad** activo, Tinto revisa cada pocos segundos y, solo cuando llevas cerca de un minuto inactiva o inactivo, le avisa a macOS que hay alguien usando el Mac y mueve el cursor 1 píxel y lo devuelve. Nunca mueve el cursor mientras trabajas.

Mover el cursor requiere permiso de **Accesibilidad** (Ajustes del Sistema → Privacidad y seguridad → Accesibilidad). Tinto te abre esa pantalla.

> **Nota:** como Tinto no está firmado con un certificado pago de Apple, macOS olvida este permiso tras cada actualización. Tinto te lo recordará; solo tienes que activarlo otra vez.

## Desinstalar

Clic derecho en el grano → **Desinstalar Tinto…**. Restaura el reposo normal, quita el permiso y manda la app a la Papelera.

## Compilar desde el código

Requiere las Command Line Tools de Apple (`xcode-select --install`, gratis y sin cuenta).

```bash
git clone https://github.com/Maggi3Mae/tinto.git
cd tinto
bash scripts/install.sh      # compila e instala en /Aplicaciones
bash scripts/make-dmg.sh     # o genera un .dmg en dist/
```

Las nuevas versiones se publican solas con GitHub Actions al subir una etiqueta de versión:

```bash
git tag v1.0.0 && git push origin v1.0.0
```

## Apoyar el proyecto

Si Tinto te sirve, puedes [invitarme un café ☕](https://ko-fi.com/margaritaa).

## Licencia

[MIT](LICENSE) © Maggi3Mae
