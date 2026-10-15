// Ordine e visibilità degli elementi, condivisi da main.qml e dalle impostazioni.
//
// Ogni lista è salvata come StringList: "id" per un elemento mostrato, "-id"
// per uno nascosto, nell'ordine scelto. Gli id sconosciuti vengono scartati e
// quelli mancanti (aggiunti in versioni successive) finiscono in fondo, nascosti.
.pragma library

const PANEL_IDS = ["batteryIcon", "batteryText", "signalIcon", "signalText", "operator", "title", "media", "notifications"]
const SECTION_IDS = ["battery", "network", "bluetooth"]
const TAB_IDS = ["status", "notifications", "player", "calls"]

function parse(entries, ids) {
    const items = []
    const seen = {}
    const count = entries ? entries.length : 0
    for (let i = 0; i < count; ++i) {
        const raw = String(entries[i])
        const hidden = raw.startsWith("-")
        const id = hidden ? raw.slice(1) : raw
        if (ids.indexOf(id) < 0 || seen[id])
            continue
        seen[id] = true
        items.push({ id: id, shown: !hidden })
    }
    for (const id of ids) {
        if (!seen[id])
            items.push({ id: id, shown: false })
    }
    return items
}

function serialize(items) {
    return items.map(item => (item.shown ? "" : "-") + item.id)
}

function shown(entries, ids) {
    return parse(entries, ids).filter(item => item.shown).map(item => item.id)
}
