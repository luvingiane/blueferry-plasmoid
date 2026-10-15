// Stateless helpers: gdbus answers, photos, shell quoting, emoji.
//
// QML's JavaScript engine does not know Unicode regexes (\p{…}, the u flag):
// characters are classified by code point by hand.
.pragma library

// gdbus prints the answer as a GVariant tuple: ('…json…',) with the string in
// single quotes (or double quotes when it contains one) and special characters
// escaped. Returns the decoded string, or null.
function gvariantString(text) {
    const match = /^\s*\((['"])([\s\S]*)\1,\)\s*$/.exec(text || "")
    if (!match)
        return null
    return gvariantUnescape(match[2])
}

// The content of a GVariant string literal without its escapes.
function gvariantUnescape(body) {
    const simple = { a: "\x07", b: "\b", f: "\f", n: "\n", r: "\r", t: "\t", v: "\v" }
    return body.replace(/\\(u[0-9a-fA-F]{4}|U[0-9a-fA-F]{8}|x[0-9a-fA-F]{2}|[\s\S])/g,
        (all, esc) => {
            if (esc.length > 1)
                return String.fromCodePoint(parseInt(esc.slice(1), 16))
            return simple[esc] !== undefined ? simple[esc] : esc
        })
}

// The string value of a key in an a{sv} dictionary printed by gdbus, for
// example 'xesam:title': <"Twilight's…"> or 'xesam:artist': <['…']> (for an
// array the first element counts). "" when the key is missing.
function gvariantField(text, key) {
    const escaped = key.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")
    const re = new RegExp("'" + escaped + "': <\\[?(?:objectpath )?(['\"])((?:\\\\.|(?!\\1)[\\s\\S])*)\\1")
    const match = re.exec(text || "")
    return match ? gvariantUnescape(match[2]) : ""
}

// A number from an a{sv} key: 'mpris:length': <int64 456733000>.
function gvariantNumber(text, key) {
    const escaped = key.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")
    const match = new RegExp("'" + escaped + "': <(?:u?int\\d+ |double )?(-?[0-9.]+)>").exec(text || "")
    return match ? Number(match[1]) : NaN
}

// A BlueFerry method's JSON answer, or undefined if unreadable.
function gvariantJson(text) {
    const json = gvariantString(text)
    if (json === null)
        return undefined
    try {
        return JSON.parse(json)
    } catch (e) {
        return undefined
    }
}

// A byte array printed by gdbus: ([byte 0xff, 0xd8, …],) or (@ay [],).
function gvariantBytes(text) {
    const body = /\[([^\]]*)\]/.exec(text || "")
    if (!body)
        return []
    const bytes = []
    const re = /0x([0-9a-fA-F]{2})/g
    let match
    while ((match = re.exec(body[1])) !== null)
        bytes.push(parseInt(match[1], 16))
    return bytes
}

const BASE64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

function base64(bytes) {
    const out = []
    for (let i = 0; i < bytes.length; i += 3) {
        const a = bytes[i]
        const b = bytes[i + 1]
        const c = bytes[i + 2]
        out.push(BASE64[a >> 2],
            BASE64[((a & 3) << 4) | ((b === undefined ? 0 : b) >> 4)],
            b === undefined ? "=" : BASE64[((b & 15) << 2) | ((c === undefined ? 0 : c) >> 6)],
            c === undefined ? "=" : BASE64[c & 63])
    }
    return out.join("")
}

// An image as a data URI, only if the first bytes really are JPEG or PNG.
function imageUri(bytes) {
    if (bytes.length > 4 && bytes[0] === 0xff && bytes[1] === 0xd8)
        return "data:image/jpeg;base64," + base64(bytes)
    if (bytes.length > 8 && bytes[0] === 0x89 && bytes[1] === 0x50 && bytes[2] === 0x4e && bytes[3] === 0x47)
        return "data:image/png;base64," + base64(bytes)
    return ""
}

// An argument that is safe for /bin/sh.
function shellQuote(text) {
    return "'" + String(text).replace(/'/g, "'\\''") + "'"
}

// A phone number as the iPhone reports it; anything else is rejected before it
// ends up in a command.
function isPhoneAddress(text) {
    return typeof text === "string" && /^[+0-9][0-9 ()*#+.-]{0,39}$/.test(text)
}

function escapeHtml(text) {
    return String(text).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;")
}

function isEmoji(cp) {
    return (cp >= 0x1F000 && cp <= 0x1FAFF) || (cp >= 0x2600 && cp <= 0x27BF)
        || (cp >= 0x2300 && cp <= 0x23FF) || (cp >= 0x2B00 && cp <= 0x2BFF)
}

// Characters that bind to the preceding emoji: ZWJ, variation selector, keycap
// and regional flag tags.
function isJoiner(cp) {
    return cp === 0x200D || cp === 0xFE0F || cp === 0x20E3 || (cp >= 0xE0020 && cp <= 0xE007F)
}

// Text for Text.StyledText: the rest stays in the theme font, emoji sequences
// switch to the chosen font (Apple Color Emoji, as on the iPhone).
function styled(text, emojiFont) {
    if (text === null || text === undefined)
        return ""
    const runs = []   // [{ emoji: bool, text: string }]
    for (const ch of String(text)) {
        const cp = ch.codePointAt(0)
        const last = runs.length > 0 ? runs[runs.length - 1] : null
        if (isJoiner(cp)) {
            if (last && !last.emoji && (cp === 0xFE0F || cp === 0x20E3)) {
                // "1️⃣", "©️": the character before the selector becomes an
                // emoji.
                const chars = Array.from(last.text)
                const base = chars.pop()
                last.text = chars.join("")
                runs.push({ emoji: true, text: base + ch })
            } else if (last) {
                last.text += ch
            }
            continue
        }
        const emoji = isEmoji(cp)
        if (last && last.emoji === emoji)
            last.text += ch
        else
            runs.push({ emoji: emoji, text: ch })
    }
    const face = escapeHtml(emojiFont || "")
    return runs.filter(run => run.text !== "").map(run => {
        const html = escapeHtml(run.text).replace(/\n/g, "<br>")
        return run.emoji && face !== "" ? '<font face="' + face + '">' + html + "</font>" : html
    }).join("")
}

// Initials for the avatar of a contact without a photo: the first letter of the
// first and the last word that does not start with an emoji or a symbol.
function initials(name) {
    const words = String(name || "").trim().split(/\s+/).filter(word => {
        const cp = word.codePointAt(0)
        return cp !== undefined && !isEmoji(cp) && /[0-9A-Za-zÀ-ɏͰ-ӿ]/.test(String.fromCodePoint(cp))
    })
    if (words.length === 0)
        return ""
    const first = Array.from(words[0])[0]
    const second = words.length > 1 ? Array.from(words[words.length - 1])[0] : ""
    return (first + second).toUpperCase()
}

// A notification's text without the characters that cannot be seen. BlueFerry
// replaces controls and text direction marks with "�" (the bidi isolates
// Discord wraps names in): they are invisible on iOS, so they go away here,
// along with the other invisible format characters.
function cleanText(text) {
    let out = ""
    for (const ch of String(text || "")) {
        const cp = ch.codePointAt(0)
        if (cp === 0xFFFD || cp === 0x200B || cp === 0xFEFF || cp === 0x200E || cp === 0x200F
                || (cp >= 0x202A && cp <= 0x202E) || (cp >= 0x2066 && cp <= 0x2069))
            continue
        out += ch
    }
    return out.replace(/\(\s*\)|\[\s*\]/g, "").replace(/[ \t]{2,}/g, " ")
        .replace(/ +\n/g, "\n").replace(/\n{3,}/g, "\n\n").trim()
}

// Icon names to try for an iPhone app, from the most specific to the most
// generic. Icon themes usually name them after the app in lower case. The
// aliases cover the system apps under their English and Italian iOS names.
const ICON_ALIASES = {
    "telegram": ["org.telegram.desktop", "telegram"],
    "whatsapp": ["whatsapp", "com.github.eneshecan.whatsappforlinux"],
    "messaggi": ["dialog-messages", "kdeconnect-sms"],
    "messages": ["dialog-messages", "kdeconnect-sms"],
    "mail": ["mail-client", "internet-mail"],
    "posta": ["mail-client", "internet-mail"],
    "calendario": ["office-calendar"],
    "calendar": ["office-calendar"],
    "telefono": ["call-start"],
    "phone": ["call-start"],
    "facetime": ["facetime", "camera-web"],
    "foto": ["multimedia-photo-viewer"],
    "photos": ["multimedia-photo-viewer"],
    "musica": ["apple-music", "multimedia-audio-player"],
    "music": ["apple-music", "multimedia-audio-player"],
    "x": ["x", "twitter"],
    "teams": ["teams", "microsoft-teams"],
    "youtube": ["youtube", "com.github.ztefn.youtube"],
    "app store": ["appstore", "system-software-install"]
}

function iconCandidates(appName) {
    const name = String(appName || "").trim().toLowerCase()
    const names = []
    const add = value => {
        if (value && names.indexOf(value) < 0)
            names.push(value)
    }
    for (const alias of ICON_ALIASES[name] || [])
        add(alias)
    add(name.replace(/\s+/g, "-"))
    add(name.replace(/[^0-9a-z]+/g, ""))
    const first = name.split(/\s+/)[0]
    if (first !== name)
        add(first)
    return names
}

// Compares two track titles, ignoring case, accents, spaces and punctuation.
function sameTitle(a, b) {
    const norm = text => String(text || "").toLowerCase().normalize("NFKD")
        .replace(/[̀-ͯ]/g, "").replace(/[^0-9a-z]+/g, "")
    const x = norm(a)
    return x !== "" && x === norm(b)
}
