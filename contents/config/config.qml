// Le pagine della finestra delle impostazioni.
import QtQuick
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: i18n("Generale")
        icon: "configure"
        source: "configGeneral.qml"
    }
}
