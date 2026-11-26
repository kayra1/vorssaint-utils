// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Everything the menu bar manager says: its Settings page, the categories
/// panel and the tooltip on its arrow.
struct MenuBarManagerStrings {
    let title: String
    let hubDescription: String
    let enableLabel: String
    let enableCaption: String
    let requiresMacOS27: String
    let applyFailed: String
    let showOnHover: String
    let rehideLabel: String
    let rehideNever: String
    let rehideSecondsFormat: String
    let clickOpensCategories: String
    let showNow: String
    let hideNow: String
    let layoutSection: String
    let layoutPermission: String
    let sectionVisible: String
    let sectionHidden: String
    let sectionAlwaysHidden: String
    let refresh: String
    let categoriesSection: String
    let categoriesCaption: String
    let categoryLabel: String
    let uncategorized: String
    let newCategory: String
    let addCategory: String
    let deleteCategory: String
    let noIcons: String
    let openSettings: String
    let layoutCaption: String
    let alwaysShown: String
}

extension FeatureStrings {
    static func menuBarManager(_ language: AppLanguage) -> MenuBarManagerStrings {
        switch language {
        case .enUS: return .enUS
        case .ptBR: return .ptBR
        case .tr: return .tr
        case .ru: return .ru
        case .es: return .es
        case .sk: return .sk
        case .de: return .de
        case .fr: return .fr
        case .it: return .it
        case .ja: return .ja
        case .ko: return .ko
        case .uk: return .uk
        case .zhHans: return .zhHans
        case .zhTW: return .zhTW
        case .zhHK: return .zhHK
        }
    }
}

extension MenuBarManagerStrings {
    static let enUS = MenuBarManagerStrings(
        title: "Menu Bar Manager",
        hubDescription: "Hide other apps’ menu bar icons and group them into categories",
        enableLabel: "Manage menu bar icons",
        enableCaption: "Adds an arrow to the menu bar. Click it to show or hide the apps you put in the Hidden section; Option-click it to also show the Always hidden ones. Quitting Vorssaint or turning this off brings every icon back.",
        requiresMacOS27: "Needs macOS 27 or later.",
        applyFailed: "The menu bar could not be changed, so nothing is hidden. Open System Settings > Menu Bar to check that the apps are still listed there.",
        showOnHover: "Show hidden icons when the pointer rests on the menu bar",
        rehideLabel: "Hide again after",
        rehideNever: "Never",
        rehideSecondsFormat: "%d seconds",
        clickOpensCategories: "Click the arrow to open categories, right-click to show hidden icons",
        showNow: "Show hidden icons",
        hideNow: "Hide icons",
        layoutSection: "Layout",
        layoutPermission: "Listing and moving the icons of other apps needs Accessibility.",
        sectionVisible: "Visible",
        sectionHidden: "Hidden",
        sectionAlwaysHidden: "Always hidden",
        refresh: "Refresh",
        categoriesSection: "Categories",
        categoriesCaption: "Group icons under names of your own. Right-click the arrow in the menu bar to open them, then click an icon to use it, even while it is hidden.",
        categoryLabel: "Category",
        uncategorized: "Uncategorized",
        newCategory: "New category",
        addCategory: "Add",
        deleteCategory: "Delete category",
        noIcons: "No menu bar icons found",
        openSettings: "Menu Bar Manager Settings…",
        layoutCaption: "Choose a section for each app. macOS hides whole apps, so all icons of an app move together. The system’s own icons and Vorssaint always stay.",
        alwaysShown: "Always shown"
    )
    static let ptBR = MenuBarManagerStrings(
        title: "Gerenciador da barra de menus",
        hubDescription: "Oculte os ícones de outros apps na barra de menus e agrupe-os em categorias",
        enableLabel: "Gerenciar ícones da barra de menus",
        enableCaption: "Adiciona uma seta à barra de menus. Clique nela para mostrar ou ocultar os apps que você colocou na seção Ocultos; com Option pressionado, ela também mostra os Sempre ocultos. Encerrar o Vorssaint ou desativar esta opção traz todos os ícones de volta.",
        requiresMacOS27: "Requer o macOS 27 ou posterior.",
        applyFailed: "Não foi possível alterar a barra de menus, então nada foi ocultado. Abra Ajustes do Sistema > Barra de Menus para conferir se os apps continuam listados lá.",
        showOnHover: "Mostrar ícones ocultos quando o cursor parar na barra de menus",
        rehideLabel: "Ocultar novamente após",
        rehideNever: "Nunca",
        rehideSecondsFormat: "%d segundos",
        clickOpensCategories: "Clicar na seta abre as categorias, o clique direito mostra os ícones ocultos",
        showNow: "Mostrar ícones ocultos",
        hideNow: "Ocultar ícones",
        layoutSection: "Disposição",
        layoutPermission: "Listar e mover os ícones de outros apps exige Acessibilidade.",
        sectionVisible: "Visíveis",
        sectionHidden: "Ocultos",
        sectionAlwaysHidden: "Sempre ocultos",
        refresh: "Atualizar",
        categoriesSection: "Categorias",
        categoriesCaption: "Agrupe ícones com nomes seus. Clique com o botão direito na seta da barra de menus para abri-las e clique em um ícone para usá-lo, mesmo que esteja oculto.",
        categoryLabel: "Categoria",
        uncategorized: "Sem categoria",
        newCategory: "Nova categoria",
        addCategory: "Adicionar",
        deleteCategory: "Apagar categoria",
        noIcons: "Nenhum ícone encontrado na barra de menus",
        openSettings: "Ajustes do gerenciador da barra de menus…",
        layoutCaption: "Escolha uma seção para cada app. O macOS oculta apps inteiros, então todos os ícones de um app se movem juntos. Os ícones do sistema e o Vorssaint sempre ficam visíveis.",
        alwaysShown: "Sempre visível"
    )
    static let tr = MenuBarManagerStrings(
        title: "Menü Çubuğu Yöneticisi",
        hubDescription: "Diğer uygulamaların menü çubuğu simgelerini gizleyin ve kategorilere ayırın",
        enableLabel: "Menü çubuğu simgelerini yönet",
        enableCaption: "Menü çubuğuna bir ok ekler. Gizli bölümüne koyduğunuz uygulamaları göstermek veya gizlemek için oka tıklayın; Her zaman gizli olanları da göstermek için Option tuşuyla tıklayın. Vorssaint’ten çıkmak veya bu seçeneği kapatmak tüm simgeleri geri getirir.",
        requiresMacOS27: "macOS 27 veya sonrası gerekir.",
        applyFailed: "Menü çubuğu değiştirilemediği için hiçbir şey gizlenmedi. Uygulamaların hâlâ orada listelendiğini görmek için Sistem Ayarları > Menü Çubuğu’nu açın.",
        showOnHover: "İmleç menü çubuğunda durduğunda gizli simgeleri göster",
        rehideLabel: "Şu süreden sonra yeniden gizle",
        rehideNever: "Asla",
        rehideSecondsFormat: "%d saniye",
        clickOpensCategories: "Oka tıklamak kategorileri açsın, sağ tıklamak gizli simgeleri göstersin",
        showNow: "Gizli simgeleri göster",
        hideNow: "Simgeleri gizle",
        layoutSection: "Yerleşim",
        layoutPermission: "Diğer uygulamaların simgelerini listelemek ve taşımak için Erişilebilirlik izni gerekir.",
        sectionVisible: "Görünür",
        sectionHidden: "Gizli",
        sectionAlwaysHidden: "Her zaman gizli",
        refresh: "Yenile",
        categoriesSection: "Kategoriler",
        categoriesCaption: "Simgeleri kendi verdiğiniz adlar altında gruplayın. Açmak için menü çubuğundaki oka sağ tıklayın, ardından gizli olsa bile kullanmak istediğiniz simgeye tıklayın.",
        categoryLabel: "Kategori",
        uncategorized: "Kategorisiz",
        newCategory: "Yeni kategori",
        addCategory: "Ekle",
        deleteCategory: "Kategoriyi sil",
        noIcons: "Menü çubuğu simgesi bulunamadı",
        openSettings: "Menü Çubuğu Yöneticisi Ayarları…",
        layoutCaption: "Her uygulama için bir bölüm seçin. macOS uygulamaları bütün olarak gizler, bu yüzden bir uygulamanın tüm simgeleri birlikte taşınır. Sistemin kendi simgeleri ve Vorssaint her zaman görünür kalır.",
        alwaysShown: "Her zaman görünür"
    )
    static let ru = MenuBarManagerStrings(
        title: "Менеджер строки меню",
        hubDescription: "Скрывайте значки других приложений в строке меню и группируйте их по категориям",
        enableLabel: "Управлять значками строки меню",
        enableCaption: "Добавляет в строку меню стрелку. Нажмите её, чтобы показать или скрыть приложения из раздела «Скрытые»; нажатие с Option показывает и всегда скрытые. Выход из Vorssaint или отключение этой функции возвращает все значки.",
        requiresMacOS27: "Требуется macOS 27 или новее.",
        applyFailed: "Не удалось изменить строку меню, поэтому ничего не скрыто. Откройте Системные настройки > Строка меню и проверьте, что приложения там по-прежнему есть.",
        showOnHover: "Показывать скрытые значки, когда указатель задерживается на строке меню",
        rehideLabel: "Скрывать снова через",
        rehideNever: "Никогда",
        rehideSecondsFormat: "%d секунд",
        clickOpensCategories: "Нажатие на стрелку открывает категории, правый клик показывает скрытые значки",
        showNow: "Показать скрытые значки",
        hideNow: "Скрыть значки",
        layoutSection: "Расположение",
        layoutPermission: "Чтобы видеть и перемещать значки других приложений, нужен Универсальный доступ.",
        sectionVisible: "Видимые",
        sectionHidden: "Скрытые",
        sectionAlwaysHidden: "Всегда скрытые",
        refresh: "Обновить",
        categoriesSection: "Категории",
        categoriesCaption: "Группируйте значки под своими названиями. Нажмите стрелку в строке меню правой кнопкой, чтобы открыть категории, затем нажмите значок, чтобы воспользоваться им, даже если он скрыт.",
        categoryLabel: "Категория",
        uncategorized: "Без категории",
        newCategory: "Новая категория",
        addCategory: "Добавить",
        deleteCategory: "Удалить категорию",
        noIcons: "Значки строки меню не найдены",
        openSettings: "Настройки менеджера строки меню…",
        layoutCaption: "Выберите раздел для каждого приложения. macOS скрывает приложения целиком, поэтому все значки приложения перемещаются вместе. Системные значки и Vorssaint видны всегда.",
        alwaysShown: "Всегда видимые"
    )
    static let es = MenuBarManagerStrings(
        title: "Gestor de la barra de menús",
        hubDescription: "Oculta los iconos de otras apps en la barra de menús y agrúpalos en categorías",
        enableLabel: "Gestionar los iconos de la barra de menús",
        enableCaption: "Añade una flecha a la barra de menús. Haz clic en ella para mostrar u ocultar las apps que pusiste en la sección Ocultos; con la tecla Opción pulsada también muestra las Siempre ocultas. Salir de Vorssaint o desactivar esta opción devuelve todos los iconos.",
        requiresMacOS27: "Requiere macOS 27 o posterior.",
        applyFailed: "No se ha podido cambiar la barra de menús, así que no se oculta nada. Abre Ajustes del Sistema > Barra de menús para comprobar que las apps siguen apareciendo allí.",
        showOnHover: "Mostrar los iconos ocultos cuando el puntero se detiene en la barra de menús",
        rehideLabel: "Volver a ocultar tras",
        rehideNever: "Nunca",
        rehideSecondsFormat: "%d segundos",
        clickOpensCategories: "El clic en la flecha abre las categorías, el clic derecho muestra los iconos ocultos",
        showNow: "Mostrar iconos ocultos",
        hideNow: "Ocultar iconos",
        layoutSection: "Disposición",
        layoutPermission: "Para listar y mover los iconos de otras apps se necesita Accesibilidad.",
        sectionVisible: "Visibles",
        sectionHidden: "Ocultos",
        sectionAlwaysHidden: "Siempre ocultos",
        refresh: "Actualizar",
        categoriesSection: "Categorías",
        categoriesCaption: "Agrupa los iconos con nombres propios. Haz clic derecho en la flecha de la barra de menús para abrirlas y haz clic en un icono para usarlo, aunque esté oculto.",
        categoryLabel: "Categoría",
        uncategorized: "Sin categoría",
        newCategory: "Nueva categoría",
        addCategory: "Añadir",
        deleteCategory: "Eliminar categoría",
        noIcons: "No se han encontrado iconos en la barra de menús",
        openSettings: "Ajustes del gestor de la barra de menús…",
        layoutCaption: "Elige una sección para cada app. macOS oculta apps enteras, así que todos los iconos de una app se mueven juntos. Los iconos del sistema y Vorssaint siempre se quedan.",
        alwaysShown: "Siempre visible"
    )
    static let sk = MenuBarManagerStrings(
        title: "Správca lišty",
        hubDescription: "Skrývajte ikony iných aplikácií v lište a zoskupujte ich do kategórií",
        enableLabel: "Spravovať ikony v lište",
        enableCaption: "Pridá do lišty šípku. Kliknutím na ňu zobrazíte alebo skryjete aplikácie, ktoré ste dali do sekcie Skryté; kliknutím s podržaným Option zobrazíte aj Vždy skryté. Ukončenie Vorssaint alebo vypnutie tejto voľby vráti všetky ikony.",
        requiresMacOS27: "Vyžaduje macOS 27 alebo novší.",
        applyFailed: "Lištu sa nepodarilo zmeniť, takže sa nič neskrylo. Otvorte Systémové nastavenia > Lišta a skontrolujte, či sú tam aplikácie stále uvedené.",
        showOnHover: "Zobraziť skryté ikony, keď sa ukazovateľ zastaví na lište",
        rehideLabel: "Znova skryť po",
        rehideNever: "Nikdy",
        rehideSecondsFormat: "%d sekúnd",
        clickOpensCategories: "Kliknutie na šípku otvorí kategórie, kliknutie pravým tlačidlom zobrazí skryté ikony",
        showNow: "Zobraziť skryté ikony",
        hideNow: "Skryť ikony",
        layoutSection: "Rozloženie",
        layoutPermission: "Na zobrazenie a presúvanie ikon iných aplikácií je potrebné Zjednodušenie ovládania.",
        sectionVisible: "Viditeľné",
        sectionHidden: "Skryté",
        sectionAlwaysHidden: "Vždy skryté",
        refresh: "Obnoviť",
        categoriesSection: "Kategórie",
        categoriesCaption: "Zoskupte ikony pod vlastnými názvami. Otvoríte ich kliknutím pravým tlačidlom na šípku v lište, potom kliknite na ikonu, ktorú chcete použiť, aj keď je skrytá.",
        categoryLabel: "Kategória",
        uncategorized: "Bez kategórie",
        newCategory: "Nová kategória",
        addCategory: "Pridať",
        deleteCategory: "Vymazať kategóriu",
        noIcons: "V lište sa nenašli žiadne ikony",
        openSettings: "Nastavenia správcu lišty…",
        layoutCaption: "Vyberte sekciu pre každú aplikáciu. macOS skrýva celé aplikácie, takže všetky ikony aplikácie sa presúvajú spolu. Systémové ikony a Vorssaint zostávajú vždy viditeľné.",
        alwaysShown: "Vždy zobrazené"
    )
    static let de = MenuBarManagerStrings(
        title: "Menüleisten-Manager",
        hubDescription: "Symbole anderer Apps in der Menüleiste ausblenden und in Kategorien gruppieren",
        enableLabel: "Menüleistensymbole verwalten",
        enableCaption: "Fügt der Menüleiste einen Pfeil hinzu. Klicke darauf, um die Apps im Bereich „Ausgeblendet“ zu zeigen oder auszublenden; mit gedrückter Wahltaste werden auch die immer ausgeblendeten gezeigt. Wenn du Vorssaint beendest oder dies ausschaltest, kommen alle Symbole zurück.",
        requiresMacOS27: "Erfordert macOS 27 oder neuer.",
        applyFailed: "Die Menüleiste konnte nicht geändert werden, daher ist nichts ausgeblendet. Öffne Systemeinstellungen > Menüleiste und prüfe, ob die Apps dort noch aufgeführt sind.",
        showOnHover: "Ausgeblendete Symbole zeigen, wenn der Zeiger auf der Menüleiste ruht",
        rehideLabel: "Wieder ausblenden nach",
        rehideNever: "Nie",
        rehideSecondsFormat: "%d Sekunden",
        clickOpensCategories: "Klick auf den Pfeil öffnet die Kategorien, Rechtsklick zeigt ausgeblendete Symbole",
        showNow: "Ausgeblendete Symbole zeigen",
        hideNow: "Symbole ausblenden",
        layoutSection: "Anordnung",
        layoutPermission: "Zum Auflisten und Verschieben der Symbole anderer Apps wird die Bedienungshilfen-Freigabe benötigt.",
        sectionVisible: "Sichtbar",
        sectionHidden: "Ausgeblendet",
        sectionAlwaysHidden: "Immer ausgeblendet",
        refresh: "Aktualisieren",
        categoriesSection: "Kategorien",
        categoriesCaption: "Gruppiere Symbole unter eigenen Namen. Öffne sie per Rechtsklick auf den Pfeil in der Menüleiste und klicke dann auf ein Symbol, um es zu verwenden, auch wenn es ausgeblendet ist.",
        categoryLabel: "Kategorie",
        uncategorized: "Ohne Kategorie",
        newCategory: "Neue Kategorie",
        addCategory: "Hinzufügen",
        deleteCategory: "Kategorie löschen",
        noIcons: "Keine Menüleistensymbole gefunden",
        openSettings: "Einstellungen für den Menüleisten-Manager …",
        layoutCaption: "Wähle für jede App einen Bereich. macOS blendet ganze Apps aus, daher bewegen sich alle Symbole einer App gemeinsam. Die Systemsymbole und Vorssaint bleiben immer sichtbar.",
        alwaysShown: "Immer sichtbar"
    )
    static let fr = MenuBarManagerStrings(
        title: "Gestionnaire de la barre des menus",
        hubDescription: "Masquez les icônes des autres apps dans la barre des menus et regroupez-les par catégorie",
        enableLabel: "Gérer les icônes de la barre des menus",
        enableCaption: "Ajoute une flèche à la barre des menus. Cliquez dessus pour afficher ou masquer les apps placées dans la section Masquées\u{00A0}; avec la touche Option, elle affiche aussi les apps toujours masquées. Quitter Vorssaint ou désactiver cette option fait revenir toutes les icônes.",
        requiresMacOS27: "Nécessite macOS 27 ou version ultérieure.",
        applyFailed: "Impossible de modifier la barre des menus, rien n’est donc masqué. Ouvrez Réglages Système > Barre des menus pour vérifier que les apps y figurent toujours.",
        showOnHover: "Afficher les icônes masquées quand le pointeur s’arrête sur la barre des menus",
        rehideLabel: "Masquer à nouveau après",
        rehideNever: "Jamais",
        rehideSecondsFormat: "%d secondes",
        clickOpensCategories: "Le clic sur la flèche ouvre les catégories, le clic droit affiche les icônes masquées",
        showNow: "Afficher les icônes masquées",
        hideNow: "Masquer les icônes",
        layoutSection: "Disposition",
        layoutPermission: "Lister et déplacer les icônes des autres apps nécessite l’autorisation Accessibilité.",
        sectionVisible: "Visibles",
        sectionHidden: "Masquées",
        sectionAlwaysHidden: "Toujours masquées",
        refresh: "Actualiser",
        categoriesSection: "Catégories",
        categoriesCaption: "Regroupez les icônes sous vos propres noms. Faites un clic droit sur la flèche de la barre des menus pour les ouvrir, puis cliquez sur une icône pour l’utiliser, même si elle est masquée.",
        categoryLabel: "Catégorie",
        uncategorized: "Sans catégorie",
        newCategory: "Nouvelle catégorie",
        addCategory: "Ajouter",
        deleteCategory: "Supprimer la catégorie",
        noIcons: "Aucune icône trouvée dans la barre des menus",
        openSettings: "Réglages du gestionnaire de la barre des menus…",
        layoutCaption: "Choisissez une section pour chaque app. macOS masque des apps entières, toutes les icônes d’une app se déplacent donc ensemble. Les icônes du système et Vorssaint restent toujours affichées.",
        alwaysShown: "Toujours affichée"
    )
    static let it = MenuBarManagerStrings(
        title: "Gestore della barra dei menu",
        hubDescription: "Nascondi le icone delle altre app nella barra dei menu e raggruppale in categorie",
        enableLabel: "Gestisci le icone della barra dei menu",
        enableCaption: "Aggiunge una freccia alla barra dei menu. Fai clic per mostrare o nascondere le app che hai messo nella sezione Nascoste; con Opzione premuto mostra anche quelle sempre nascoste. Uscire da Vorssaint o disattivare questa opzione riporta tutte le icone.",
        requiresMacOS27: "Richiede macOS 27 o versioni successive.",
        applyFailed: "Non è stato possibile modificare la barra dei menu, quindi non è nascosto nulla. Apri Impostazioni di Sistema > Barra dei menu per verificare che le app siano ancora elencate.",
        showOnHover: "Mostra le icone nascoste quando il puntatore si ferma sulla barra dei menu",
        rehideLabel: "Nascondi di nuovo dopo",
        rehideNever: "Mai",
        rehideSecondsFormat: "%d secondi",
        clickOpensCategories: "Il clic sulla freccia apre le categorie, il clic destro mostra le icone nascoste",
        showNow: "Mostra icone nascoste",
        hideNow: "Nascondi icone",
        layoutSection: "Disposizione",
        layoutPermission: "Per elencare e spostare le icone delle altre app serve Accessibilità.",
        sectionVisible: "Visibili",
        sectionHidden: "Nascoste",
        sectionAlwaysHidden: "Sempre nascoste",
        refresh: "Aggiorna",
        categoriesSection: "Categorie",
        categoriesCaption: "Raggruppa le icone sotto nomi scelti da te. Fai clic destro sulla freccia nella barra dei menu per aprirle, poi fai clic su un’icona per usarla, anche se è nascosta.",
        categoryLabel: "Categoria",
        uncategorized: "Senza categoria",
        newCategory: "Nuova categoria",
        addCategory: "Aggiungi",
        deleteCategory: "Elimina categoria",
        noIcons: "Nessuna icona trovata nella barra dei menu",
        openSettings: "Impostazioni del gestore della barra dei menu…",
        layoutCaption: "Scegli una sezione per ogni app. macOS nasconde app intere, quindi tutte le icone di un’app si spostano insieme. Le icone di sistema e Vorssaint restano sempre visibili.",
        alwaysShown: "Sempre visibile"
    )
    static let ja = MenuBarManagerStrings(
        title: "メニューバーマネージャ",
        hubDescription: "ほかのアプリのメニューバーアイコンを隠し、カテゴリにまとめる",
        enableLabel: "メニューバーのアイコンを管理",
        enableCaption: "メニューバーに矢印を追加します。矢印をクリックすると「非表示」セクションのアプリを表示または非表示にします。Optionキーを押しながらクリックすると「常に非表示」のアプリも表示します。Vorssaintを終了するか、この機能をオフにするとすべてのアイコンが戻ります。",
        requiresMacOS27: "macOS 27以降が必要です。",
        applyFailed: "メニューバーを変更できなかったため、何も隠れていません。システム設定 > メニューバーを開き、アプリが引き続き表示されているか確認してください。",
        showOnHover: "ポインタがメニューバー上で止まったら隠れたアイコンを表示",
        rehideLabel: "再び隠すまでの時間",
        rehideNever: "しない",
        rehideSecondsFormat: "%d秒",
        clickOpensCategories: "矢印のクリックでカテゴリを開き、右クリックで隠れたアイコンを表示",
        showNow: "隠れたアイコンを表示",
        hideNow: "アイコンを隠す",
        layoutSection: "レイアウト",
        layoutPermission: "ほかのアプリのアイコンを一覧表示して移動するには、アクセシビリティの許可が必要です。",
        sectionVisible: "表示",
        sectionHidden: "非表示",
        sectionAlwaysHidden: "常に非表示",
        refresh: "更新",
        categoriesSection: "カテゴリ",
        categoriesCaption: "アイコンを好きな名前でまとめます。メニューバーの矢印を右クリックして開き、アイコンをクリックすると、隠れていても使えます。",
        categoryLabel: "カテゴリ",
        uncategorized: "カテゴリなし",
        newCategory: "新規カテゴリ",
        addCategory: "追加",
        deleteCategory: "カテゴリを削除",
        noIcons: "メニューバーのアイコンが見つかりません",
        openSettings: "メニューバーマネージャの設定…",
        layoutCaption: "アプリごとにセクションを選びます。macOSはアプリ単位で隠すため、同じアプリのアイコンはまとめて移動します。システムのアイコンとVorssaintは常に表示されます。",
        alwaysShown: "常に表示"
    )
    static let ko = MenuBarManagerStrings(
        title: "메뉴 막대 관리자",
        hubDescription: "다른 앱의 메뉴 막대 아이콘을 가리고 카테고리로 묶습니다",
        enableLabel: "메뉴 막대 아이콘 관리",
        enableCaption: "메뉴 막대에 화살표를 추가합니다. 화살표를 클릭하면 가려짐 구역에 넣은 앱을 보이거나 가립니다. Option 키를 누른 채 클릭하면 항상 가려짐 앱도 보입니다. Vorssaint를 종료하거나 이 기능을 끄면 모든 아이콘이 돌아옵니다.",
        requiresMacOS27: "macOS 27 이상이 필요합니다.",
        applyFailed: "메뉴 막대를 변경할 수 없어 아무것도 가리지 않았습니다. 시스템 설정 > 메뉴 막대를 열어 앱이 아직 목록에 있는지 확인하세요.",
        showOnHover: "포인터가 메뉴 막대에 머물면 가려진 아이콘 보기",
        rehideLabel: "다시 가리기까지",
        rehideNever: "안 함",
        rehideSecondsFormat: "%d초",
        clickOpensCategories: "화살표를 클릭하면 카테고리 열기, 오른쪽 클릭하면 가려진 아이콘 보기",
        showNow: "가려진 아이콘 보기",
        hideNow: "아이콘 가리기",
        layoutSection: "배치",
        layoutPermission: "다른 앱의 아이콘을 나열하고 옮기려면 손쉬운 사용 권한이 필요합니다.",
        sectionVisible: "표시됨",
        sectionHidden: "가려짐",
        sectionAlwaysHidden: "항상 가려짐",
        refresh: "새로 고침",
        categoriesSection: "카테고리",
        categoriesCaption: "아이콘을 원하는 이름으로 묶으세요. 메뉴 막대의 화살표를 오른쪽 클릭해 연 다음 아이콘을 클릭하면 가려져 있어도 사용할 수 있습니다.",
        categoryLabel: "카테고리",
        uncategorized: "카테고리 없음",
        newCategory: "새 카테고리",
        addCategory: "추가",
        deleteCategory: "카테고리 삭제",
        noIcons: "메뉴 막대 아이콘을 찾을 수 없습니다",
        openSettings: "메뉴 막대 관리자 설정…",
        layoutCaption: "앱마다 구역을 선택하세요. macOS는 앱 단위로 가리므로 한 앱의 아이콘은 함께 이동합니다. 시스템 아이콘과 Vorssaint는 항상 표시됩니다.",
        alwaysShown: "항상 표시"
    )
    static let uk = MenuBarManagerStrings(
        title: "Менеджер смуги меню",
        hubDescription: "Приховуйте значки інших програм у смузі меню й групуйте їх за категоріями",
        enableLabel: "Керувати значками смуги меню",
        enableCaption: "Додає до смуги меню стрілку. Клацніть її, щоб показати або приховати програми з розділу «Приховані»; клацання з Option показує й завжди приховані. Вихід із Vorssaint або вимкнення цієї функції повертає всі значки.",
        requiresMacOS27: "Потрібна macOS 27 або новіша.",
        applyFailed: "Не вдалося змінити смугу меню, тому нічого не приховано. Відкрийте Системні параметри > Смуга меню й перевірте, чи програми досі там є.",
        showOnHover: "Показувати приховані значки, коли вказівник затримується на смузі меню",
        rehideLabel: "Приховувати знову через",
        rehideNever: "Ніколи",
        rehideSecondsFormat: "%d секунд",
        clickOpensCategories: "Клацання стрілки відкриває категорії, клацання правою кнопкою показує приховані значки",
        showNow: "Показати приховані значки",
        hideNow: "Приховати значки",
        layoutSection: "Розташування",
        layoutPermission: "Щоб бачити й переміщати значки інших програм, потрібен дозвіл Доступності.",
        sectionVisible: "Видимі",
        sectionHidden: "Приховані",
        sectionAlwaysHidden: "Завжди приховані",
        refresh: "Оновити",
        categoriesSection: "Категорії",
        categoriesCaption: "Групуйте значки під власними назвами. Клацніть стрілку у смузі меню правою кнопкою, щоб відкрити категорії, а потім клацніть значок, щоб скористатися ним, навіть якщо він прихований.",
        categoryLabel: "Категорія",
        uncategorized: "Без категорії",
        newCategory: "Нова категорія",
        addCategory: "Додати",
        deleteCategory: "Видалити категорію",
        noIcons: "Значків смуги меню не знайдено",
        openSettings: "Параметри менеджера смуги меню…",
        layoutCaption: "Виберіть розділ для кожної програми. macOS приховує програми повністю, тому всі значки програми переміщаються разом. Системні значки та Vorssaint видно завжди.",
        alwaysShown: "Завжди видимі"
    )
    static let zhHans = MenuBarManagerStrings(
        title: "菜单栏管理器",
        hubDescription: "隐藏其他 App 的菜单栏图标并将其分组",
        enableLabel: "管理菜单栏图标",
        enableCaption: "在菜单栏中添加一个箭头。点按它可显示或隐藏你放入“隐藏”区域的 App；按住 Option 键点按还会显示“始终隐藏”的 App。退出 Vorssaint 或关闭此功能后，所有图标都会恢复。",
        requiresMacOS27: "需要 macOS 27 或更高版本。",
        applyFailed: "无法更改菜单栏，因此没有隐藏任何内容。打开“系统设置”>“菜单栏”，确认这些 App 仍在列表中。",
        showOnHover: "指针停留在菜单栏上时显示隐藏的图标",
        rehideLabel: "再次隐藏的时间",
        rehideNever: "永不",
        rehideSecondsFormat: "%d 秒",
        clickOpensCategories: "点按箭头打开分类，右键点按显示隐藏的图标",
        showNow: "显示隐藏的图标",
        hideNow: "隐藏图标",
        layoutSection: "布局",
        layoutPermission: "列出并移动其他 App 的图标需要辅助功能权限。",
        sectionVisible: "可见",
        sectionHidden: "隐藏",
        sectionAlwaysHidden: "始终隐藏",
        refresh: "刷新",
        categoriesSection: "分类",
        categoriesCaption: "用你自己的名称为图标分组。右键点按菜单栏中的箭头打开分类，然后点按图标即可使用，即使它处于隐藏状态。",
        categoryLabel: "分类",
        uncategorized: "未分类",
        newCategory: "新建分类",
        addCategory: "添加",
        deleteCategory: "删除分类",
        noIcons: "未找到菜单栏图标",
        openSettings: "菜单栏管理器设置…",
        layoutCaption: "为每个 App 选择一个区域。macOS 按 App 整体隐藏，因此同一 App 的所有图标会一起移动。系统自带的图标和 Vorssaint 始终保留。",
        alwaysShown: "始终显示"
    )
    static let zhTW = MenuBarManagerStrings(
        title: "選單列管理器",
        hubDescription: "隱藏其他 App 的選單列圖像並加以分組",
        enableLabel: "管理選單列圖像",
        enableCaption: "在選單列加入一個箭頭。按一下即可顯示或隱藏你放入「隱藏」區域的 App；按住 Option 鍵並按一下還會顯示「永遠隱藏」的 App。結束 Vorssaint 或關閉此功能後，所有圖像都會恢復。",
        requiresMacOS27: "需要 macOS 27 或以上版本。",
        applyFailed: "無法更改選單列，因此沒有隱藏任何項目。打開「系統設定」>「選單列」，確認這些 App 仍在列表中。",
        showOnHover: "指標停留在選單列上時顯示隱藏的圖像",
        rehideLabel: "再次隱藏的時間",
        rehideNever: "永不",
        rehideSecondsFormat: "%d 秒",
        clickOpensCategories: "按一下箭頭打開分類，按右鍵顯示隱藏的圖像",
        showNow: "顯示隱藏的圖像",
        hideNow: "隱藏圖像",
        layoutSection: "佈局",
        layoutPermission: "列出並搬移其他 App 的圖像需要輔助使用權限。",
        sectionVisible: "可見",
        sectionHidden: "隱藏",
        sectionAlwaysHidden: "永遠隱藏",
        refresh: "重新整理",
        categoriesSection: "分類",
        categoriesCaption: "用你自己的名稱為圖像分組。在選單列的箭頭上按右鍵來打開分類，然後按一下圖像即可使用，即使它處於隱藏狀態。",
        categoryLabel: "分類",
        uncategorized: "未分類",
        newCategory: "新增分類",
        addCategory: "加入",
        deleteCategory: "刪除分類",
        noIcons: "找不到選單列圖像",
        openSettings: "選單列管理器設定…",
        layoutCaption: "為每個 App 選擇一個區域。macOS 以 App 為單位隱藏，因此同一 App 的所有圖像會一起移動。系統內建的圖像和 Vorssaint 永遠保留。",
        alwaysShown: "永遠顯示"
    )
    static let zhHK = MenuBarManagerStrings(
        title: "選單列管理員",
        hubDescription: "隱藏其他 App 的選單列圖像並加以分組",
        enableLabel: "管理選單列圖像",
        enableCaption: "在選單列加入一個箭嘴。按一下即可顯示或隱藏你放入「隱藏」區域的 App；按住 Option 鍵並按一下還會顯示「永遠隱藏」的 App。結束 Vorssaint 或關閉此功能後，所有圖像都會恢復。",
        requiresMacOS27: "需要 macOS 27 或以上版本。",
        applyFailed: "無法更改選單列，因此沒有隱藏任何項目。開啟「系統設定」>「選單列」，確認這些 App 仍在列表中。",
        showOnHover: "指標停留在選單列上時顯示隱藏的圖像",
        rehideLabel: "再次隱藏的時間",
        rehideNever: "永不",
        rehideSecondsFormat: "%d 秒",
        clickOpensCategories: "按一下箭嘴開啟分類，按右鍵顯示隱藏的圖像",
        showNow: "顯示隱藏的圖像",
        hideNow: "隱藏圖像",
        layoutSection: "佈局",
        layoutPermission: "列出並移動其他 App 的圖像需要輔助使用權限。",
        sectionVisible: "可見",
        sectionHidden: "隱藏",
        sectionAlwaysHidden: "永遠隱藏",
        refresh: "重新整理",
        categoriesSection: "分類",
        categoriesCaption: "用你自己的名稱為圖像分組。在選單列的箭嘴上按右鍵來開啟分類，然後按一下圖像即可使用，即使它處於隱藏狀態。",
        categoryLabel: "分類",
        uncategorized: "未分類",
        newCategory: "新增分類",
        addCategory: "加入",
        deleteCategory: "刪除分類",
        noIcons: "找不到選單列圖像",
        openSettings: "選單列管理員設定…",
        layoutCaption: "為每個 App 選擇一個區域。macOS 以 App 為單位隱藏，因此同一 App 的所有圖像會一起移動。系統內置的圖像和 Vorssaint 永遠保留。",
        alwaysShown: "永遠顯示"
    )
}
