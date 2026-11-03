# Spanish (es) style guide

## Variant and register

- `es` is Spain Spanish (Latin America is `es-419`). Write as Apple's Spain iOS interface does.
- Address the user as "tú": "tus tarjetas", "Escribe el código", "Estás en %@". Never "usted" or "vosotros".
- Messages use the pretérito perfecto, as Apple Spain does: "No se ha podido…", "No se ha encontrado…", "Se ha añadido %@". Never "No se pudo".

## Apple terms

Ajustes (Settings), pantalla bloqueada (Lock Screen, lower case in sentences), Localización (Location Services), Notificaciones, Cámara, Editar, OK (Done), Aceptar (an alert's OK), Cancelar, Eliminar (Delete; "Borrar" is Clear), Añadir, Guardar, Exportar, Importar, Por omisión (Default), Activado/Desactivado (VoiceOver values).

## Glossary decisions

- card: tarjeta; loyalty card: tarjeta de fidelización; membership card: tarjeta de socio.
- barcode: código de barras; code (the number): código; barcode type: tipo de código de barras; QR Code: Código QR.
- scan: escanear, escaneo (the camera and the shop's scanner alike).
- Location (titles, buttons): ubicación; place (sentences): lugar; Pinned location: Ubicación marcada; map pin: marcador del mapa.
- Brightness Boost: Aumento de brillo (setting, button, announcements); Voice Control name: Brillo.
- postcode: código postal; radius: radio ("Radio de %@").
- Colours use Apple's names: Morado, Grafito, Índigo, Verde azulado, Marrón.

## Punctuation and case

- Sentence case for titles and buttons: "Añadir tarjeta", "Aún no hay tarjetas".
- Quotation marks are « »: "ningún lugar para «%@»". Open questions and exclamations with ¿ ¡.
- Purpose strings are full sentences ending in a full stop: "La cámara se usa para…", "Tu ubicación se usa para…".
- "p. ej." for "e.g.".

## Pitfalls

- Plural `many` (1 000 000, 2 000 000…) needs "de": "%lld de tarjetas". Drop any article, which cannot agree with both "el millón" and "los dos millones".
- Format names arrive localised ("Código QR"), so never put "código" before one: "%1$@ escaneado: %2$@".
- Agreement: tarjeta and ubicación are feminine ("Creada el %@", "Eliminar todas"); format names and the marcador are masculine ("Movido al norte").
- Never write units; distances arrive formatted.
