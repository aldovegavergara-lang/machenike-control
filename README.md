# Machenike Control

App independiente para macOS 15 o posterior y teclado Machenike K500-B61 por cable. No es software oficial de Machenike. Instalación local: `~/Applications/Machenike Control.app`.

## Uso

Pulsa el icono de teclado en la barra superior. El dibujo distingue la función de cada tecla de su nombre físico y muestra **Principal**, **Fn** y **Ctrl + Fn**. La capa base se lee desde macOS; la capa Fn se lee por USB cuando el permiso está disponible. La guía del manual se identifica como tal cuando no se puede leer el teclado.

En **Configuración → Teclado**, selecciona una tecla. **Actual** muestra el estado aplicado; **Acción** permite elegir su función original, otra tecla o **App o URL**. Pulsa **Guardar** para guardar y activar. Los cambios de perfiles aún no aplicados se muestran por separado con sus funciones anterior y nueva.

Para añadir un destino, pulsa **+** junto al destino. Elige cualquier `.app` con Finder, o introduce una dirección web y un nombre opcional. No hay una lista predefinida de todas las aplicaciones. Guardar el destino añade solo ese destino a la biblioteca local. Las URLs se abren en el navegador predeterminado; si omites el esquema, se añade `https://`.

**Fn + Shift + C → Chrome:** en Fn selecciona C, elige App o URL, selecciona Chrome, elige **⇧ Shift** en Además y pulsa Guardar. La capa interna produce una tecla independiente al mantener Fn; el manejador de macOS requiere además Shift. C y Shift + C sin Fn conservan su comportamiento normal. Fn + C sin Shift produce la tecla reservada y no abre Chrome. Se admiten ocho destinos simultáneos y letras con función normal comprobada en esta revisión. Las funciones RGB y las combinaciones especiales del fabricante permanecen protegidas.

Los controles Option/Alt, Command/Win, Control y Shift se reasignan en macOS por dispositivo USB `258A:0049`. Los atajos Control + flechas los gestiona macOS; Control + Fn + A/D permite acceder a las flechas de la capa compacta para cambiar de escritorio.

Las rutas utilizan F13–F20, reservadas mientras la app está abierta. Una señal equivalente desde otro teclado también puede activar el acceso. Las nuevas combinaciones Fn con letras se guardan en la matriz interna, con respaldo previo y comprobación por lectura. Al salir, la app intenta restaurar la matriz anterior y retira los manejadores de aplicaciones. Esta restauración USB requiere el permiso de Monitoreo de entrada. El estado guardado se recupera al volver a abrir. Si la lectura USB está bloqueada, los manejadores de una combinación Fn previamente guardada pueden registrarse y funcionar; la interfaz mantiene la comprobación USB como pendiente.

**Restaurar teclas** elimina las reasignaciones de la app y restaura la matriz Fn respaldada. En Ajustes puedes activar el inicio con macOS.

## RGB experimental

En **Iluminación**, pulsa **Leer teclado**. Si macOS bloquea el USB, habilita Machenike Control en **Ajustes del Sistema → Privacidad y seguridad → Monitoreo de entrada**, cierra la app y vuelve a abrirla. La firma es local: una recompilación puede requerir desactivar y reactivar ese mismo permiso. Los controles de escritura permanecen deshabilitados hasta validar la configuración y la paleta reales.

Se admiten color fijo, multicolor y brillo 0–4. Aplicar RGB selecciona iluminación fija. Se conservan los demás bytes leídos del dispositivo, se respalda el estado antes de escribir y se verifica por una lectura posterior. La correspondencia con las luces físicas necesita una prueba del usuario. La edición Fn modifica configuración de teclas, sin actualizar firmware ni bootloader. No están habilitados animaciones, velocidad, color por tecla ni macros.

La lectura y escritura RGB se probaron sobre el teclado conectado: el dispositivo confirmó el color de prueba y se restauraron su modo y paleta originales. **Deshacer último cambio RGB** permite recuperar el estado anterior. Esto confirma la respuesta USB; la apariencia física de las luces la comprueba el usuario.

Los destinos personalizados (`targets.json`), los perfiles y el estado activo se guardan en `~/Library/Application Support/Machenike Control/`. Los respaldos RGB se guardan en `RGB Backups`; los respaldos de teclas en `Fn Backups`, y la transacción Fn activa en `Fn-State.json`.

## Compilar y comprobar

Requiere Xcode y Swift. No usa dependencias externas.

```sh
./scripts/build.sh
./scripts/test.sh
```

La app se genera en `dist/Machenike Control.app`; cópiala a `~/Applications/` y ábrela. El identificador predeterminado es `io.github.machenikecontrol.app`. `MACHENIKE_BUNDLE_ID` permite mantener el identificador de una instalación existente durante el desarrollo local.

Las pruebas normales usan datos sintéticos, no requieren un teclado conectado y no modifican el dispositivo ni abren destinos externos. Los scripts locales de investigación y las capturas originales no se distribuyen. Los tests de hotkeys necesitan una sesión gráfica de macOS.

Consulta [Privacidad](PRIVACY.md), [Seguridad](SECURITY.md) y [la revisión local](Docs/security-review.md). La configuración personal y los respaldos quedan fuera de Git. El proyecto no incluye binarios de terceros, claves ni perfiles personales.

## Referencias

- [Descargas oficiales Machenike](https://www.machenike.com/offline/driverUnit): aplicación K500-B61 `MKK_App_K500-B61.8548.exe`, configuración `Cfg.ini` y etiquetas de funciones. La aplicación de Windows se extrajo para analizar sus datos, sin instalarla ni actualizar firmware.

- [Manual K500-B61 del fabricante](https://ae01.alicdn.com/kf/S970c2cc5ba5d473a95b5f22cfb0e9d77R.pdf): funciones Fn.
- [Captura USB K500 publicada en OpenRGB, issue 3365](https://gitlab.com/CalcProgrammer1/OpenRGB/-/issues/3365): colores, brillo y reportes HID del mismo VID/PID. Este VID/PID también lo usan otros teclados; por eso se valida la firma de configuración antes de habilitar escritura RGB.
- [nuga-lib, constantes de protocolo BYK916](https://github.com/mishamyrt/nuga-lib/blob/main/features/light/constants.go): corrobora los comandos de lectura de configuración y paleta. Sus asignaciones específicas de NuPhy no se usan en el K500.
- [Apple TN2450](https://developer.apple.com/library/archive/technotes/tn2450/_index.html): reasignación HID en macOS.

El protocolo estudiado se documenta en [Docs/Fn-protocol.md](Docs/Fn-protocol.md). Las capturas y vistas generadas desde configuración local se excluyen del repositorio.
