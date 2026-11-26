// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Everything the menu bar dropdown says: its Settings page, the dropdown
/// itself and the tooltip on its arrow.
struct MenuBarManagerStrings {
    let title: String
    let hubDescription: String
    let enableLabel: String
    let enableCaption: String
    let requiresMacOS27: String
    let openDropdown: String
    let permissionNeeded: String
    let categoriesSection: String
    let categoriesCaption: String
    let categoryLabel: String
    let uncategorized: String
    let newCategory: String
    let addCategory: String
    let deleteCategory: String
    let iconsSection: String
    let iconsCaption: String
    let refresh: String
    let noIcons: String
    let openSettings: String
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
        hubDescription: "Open every menu bar icon from one dropdown, grouped into categories",
        enableLabel: "Show the icon dropdown",
        enableCaption: "Adds an arrow to the menu bar. Click it to see every menu bar icon in one dropdown, grouped into your categories, and click an icon there to use it.",
        requiresMacOS27: "Needs macOS 27 or later.",
        openDropdown: "Menu bar icons",
        permissionNeeded: "Listing and opening the icons of other apps needs Accessibility.",
        categoriesSection: "Categories",
        categoriesCaption: "Name your own groups, such as Work or Media, then choose a category for each icon below.",
        categoryLabel: "Category",
        uncategorized: "Uncategorized",
        newCategory: "New category",
        addCategory: "Add",
        deleteCategory: "Delete category",
        iconsSection: "Icons",
        iconsCaption: "Every icon in the menu bar right now. Choose where each one appears in the dropdown.",
        refresh: "Refresh",
        noIcons: "No menu bar icons found",
        openSettings: "Menu Bar Manager Settings…"
    )
    static let ptBR = MenuBarManagerStrings(
        title: "Gerenciador da barra de menus",
        hubDescription: "Abra todos os ícones da barra de menus em um menu suspenso, agrupados em categorias",
        enableLabel: "Mostrar o menu de ícones",
        enableCaption: "Adiciona uma seta à barra de menus. Clique nela para ver todos os ícones da barra de menus em um menu suspenso, agrupados nas suas categorias, e clique em um ícone para usá-lo.",
        requiresMacOS27: "Requer o macOS 27 ou posterior.",
        openDropdown: "Ícones da barra de menus",
        permissionNeeded: "Listar e abrir os ícones de outros apps exige Acessibilidade.",
        categoriesSection: "Categorias",
        categoriesCaption: "Crie grupos com nomes seus, como Trabalho ou Mídia, e escolha uma categoria para cada ícone abaixo.",
        categoryLabel: "Categoria",
        uncategorized: "Sem categoria",
        newCategory: "Nova categoria",
        addCategory: "Adicionar",
        deleteCategory: "Apagar categoria",
        iconsSection: "Ícones",
        iconsCaption: "Todos os ícones que estão na barra de menus agora. Escolha onde cada um aparece no menu suspenso.",
        refresh: "Atualizar",
        noIcons: "Nenhum ícone encontrado na barra de menus",
        openSettings: "Ajustes do gerenciador da barra de menus…"
    )
    static let tr = MenuBarManagerStrings(
        title: "Menü Çubuğu Yöneticisi",
        hubDescription: "Tüm menü çubuğu simgelerini kategorilere ayrılmış tek bir açılır menüden açın",
        enableLabel: "Simge menüsünü göster",
        enableCaption: "Menü çubuğuna bir ok ekler. Tüm menü çubuğu simgelerini kategorilerinize ayrılmış tek bir açılır menüde görmek için oka tıklayın, kullanmak için oradaki bir simgeye tıklayın.",
        requiresMacOS27: "macOS 27 veya sonrası gerekir.",
        openDropdown: "Menü çubuğu simgeleri",
        permissionNeeded: "Diğer uygulamaların simgelerini listelemek ve açmak için Erişilebilirlik izni gerekir.",
        categoriesSection: "Kategoriler",
        categoriesCaption: "İş veya Medya gibi kendi gruplarınızı adlandırın, ardından aşağıda her simge için bir kategori seçin.",
        categoryLabel: "Kategori",
        uncategorized: "Kategorisiz",
        newCategory: "Yeni kategori",
        addCategory: "Ekle",
        deleteCategory: "Kategoriyi sil",
        iconsSection: "Simgeler",
        iconsCaption: "Şu anda menü çubuğundaki tüm simgeler. Her birinin açılır menüde nerede görüneceğini seçin.",
        refresh: "Yenile",
        noIcons: "Menü çubuğu simgesi bulunamadı",
        openSettings: "Menü Çubuğu Yöneticisi Ayarları…"
    )
    static let ru = MenuBarManagerStrings(
        title: "Менеджер строки меню",
        hubDescription: "Открывайте все значки строки меню из одного выпадающего списка с категориями",
        enableLabel: "Показывать список значков",
        enableCaption: "Добавляет в строку меню стрелку. Нажмите её, чтобы увидеть все значки строки меню в одном выпадающем списке, сгруппированные по вашим категориям, и нажмите значок, чтобы воспользоваться им.",
        requiresMacOS27: "Требуется macOS 27 или новее.",
        openDropdown: "Значки строки меню",
        permissionNeeded: "Чтобы видеть и открывать значки других приложений, нужен Универсальный доступ.",
        categoriesSection: "Категории",
        categoriesCaption: "Создайте свои группы, например «Работа» или «Медиа», а затем выберите категорию для каждого значка ниже.",
        categoryLabel: "Категория",
        uncategorized: "Без категории",
        newCategory: "Новая категория",
        addCategory: "Добавить",
        deleteCategory: "Удалить категорию",
        iconsSection: "Значки",
        iconsCaption: "Все значки, которые сейчас есть в строке меню. Выберите, где каждый из них появится в списке.",
        refresh: "Обновить",
        noIcons: "Значки строки меню не найдены",
        openSettings: "Настройки менеджера строки меню…"
    )
    static let es = MenuBarManagerStrings(
        title: "Gestor de la barra de menús",
        hubDescription: "Abre todos los iconos de la barra de menús desde un desplegable, agrupados en categorías",
        enableLabel: "Mostrar el desplegable de iconos",
        enableCaption: "Añade una flecha a la barra de menús. Haz clic en ella para ver todos los iconos de la barra de menús en un desplegable, agrupados en tus categorías, y haz clic en un icono para usarlo.",
        requiresMacOS27: "Requiere macOS 27 o posterior.",
        openDropdown: "Iconos de la barra de menús",
        permissionNeeded: "Para listar y abrir los iconos de otras apps se necesita Accesibilidad.",
        categoriesSection: "Categorías",
        categoriesCaption: "Pon nombre a tus propios grupos, como Trabajo o Multimedia, y elige una categoría para cada icono de abajo.",
        categoryLabel: "Categoría",
        uncategorized: "Sin categoría",
        newCategory: "Nueva categoría",
        addCategory: "Añadir",
        deleteCategory: "Eliminar categoría",
        iconsSection: "Iconos",
        iconsCaption: "Todos los iconos que hay ahora en la barra de menús. Elige dónde aparece cada uno en el desplegable.",
        refresh: "Actualizar",
        noIcons: "No se han encontrado iconos en la barra de menús",
        openSettings: "Ajustes del gestor de la barra de menús…"
    )
    static let sk = MenuBarManagerStrings(
        title: "Správca lišty",
        hubDescription: "Otvárajte všetky ikony z lišty z jednej rozbaľovacej ponuky, zoskupené do kategórií",
        enableLabel: "Zobraziť ponuku ikon",
        enableCaption: "Pridá do lišty šípku. Kliknutím na ňu uvidíte všetky ikony z lišty v jednej rozbaľovacej ponuke, zoskupené do vašich kategórií, a kliknutím na ikonu ju použijete.",
        requiresMacOS27: "Vyžaduje macOS 27 alebo novší.",
        openDropdown: "Ikony v lište",
        permissionNeeded: "Na zobrazenie a otváranie ikon iných aplikácií je potrebné Zjednodušenie ovládania.",
        categoriesSection: "Kategórie",
        categoriesCaption: "Pomenujte si vlastné skupiny, napríklad Práca alebo Médiá, a nižšie vyberte kategóriu pre každú ikonu.",
        categoryLabel: "Kategória",
        uncategorized: "Bez kategórie",
        newCategory: "Nová kategória",
        addCategory: "Pridať",
        deleteCategory: "Vymazať kategóriu",
        iconsSection: "Ikony",
        iconsCaption: "Všetky ikony, ktoré sú teraz v lište. Vyberte, kde sa každá zobrazí v ponuke.",
        refresh: "Obnoviť",
        noIcons: "V lište sa nenašli žiadne ikony",
        openSettings: "Nastavenia správcu lišty…"
    )
    static let de = MenuBarManagerStrings(
        title: "Menüleisten-Manager",
        hubDescription: "Alle Menüleistensymbole aus einem Aufklappmenü öffnen, nach Kategorien gruppiert",
        enableLabel: "Symbolmenü anzeigen",
        enableCaption: "Fügt der Menüleiste einen Pfeil hinzu. Klicke darauf, um alle Menüleistensymbole in einem Aufklappmenü nach deinen Kategorien gruppiert zu sehen, und klicke dort auf ein Symbol, um es zu verwenden.",
        requiresMacOS27: "Erfordert macOS 27 oder neuer.",
        openDropdown: "Menüleistensymbole",
        permissionNeeded: "Zum Auflisten und Öffnen der Symbole anderer Apps wird die Bedienungshilfen-Freigabe benötigt.",
        categoriesSection: "Kategorien",
        categoriesCaption: "Benenne eigene Gruppen, etwa Arbeit oder Medien, und wähle dann unten für jedes Symbol eine Kategorie.",
        categoryLabel: "Kategorie",
        uncategorized: "Ohne Kategorie",
        newCategory: "Neue Kategorie",
        addCategory: "Hinzufügen",
        deleteCategory: "Kategorie löschen",
        iconsSection: "Symbole",
        iconsCaption: "Alle Symbole, die gerade in der Menüleiste sind. Wähle, wo jedes im Aufklappmenü erscheint.",
        refresh: "Aktualisieren",
        noIcons: "Keine Menüleistensymbole gefunden",
        openSettings: "Einstellungen für den Menüleisten-Manager …"
    )
    static let fr = MenuBarManagerStrings(
        title: "Gestionnaire de la barre des menus",
        hubDescription: "Ouvrez toutes les icônes de la barre des menus depuis un menu déroulant, regroupées par catégorie",
        enableLabel: "Afficher le menu des icônes",
        enableCaption: "Ajoute une flèche à la barre des menus. Cliquez dessus pour voir toutes les icônes de la barre des menus dans un menu déroulant, regroupées selon vos catégories, puis cliquez sur une icône pour l’utiliser.",
        requiresMacOS27: "Nécessite macOS 27 ou version ultérieure.",
        openDropdown: "Icônes de la barre des menus",
        permissionNeeded: "Lister et ouvrir les icônes des autres apps nécessite l’autorisation Accessibilité.",
        categoriesSection: "Catégories",
        categoriesCaption: "Nommez vos propres groupes, comme Travail ou Médias, puis choisissez une catégorie pour chaque icône ci-dessous.",
        categoryLabel: "Catégorie",
        uncategorized: "Sans catégorie",
        newCategory: "Nouvelle catégorie",
        addCategory: "Ajouter",
        deleteCategory: "Supprimer la catégorie",
        iconsSection: "Icônes",
        iconsCaption: "Toutes les icônes présentes dans la barre des menus. Choisissez où chacune apparaît dans le menu déroulant.",
        refresh: "Actualiser",
        noIcons: "Aucune icône trouvée dans la barre des menus",
        openSettings: "Réglages du gestionnaire de la barre des menus…"
    )
    static let it = MenuBarManagerStrings(
        title: "Gestore della barra dei menu",
        hubDescription: "Apri tutte le icone della barra dei menu da un unico menu a discesa, raggruppate in categorie",
        enableLabel: "Mostra il menu delle icone",
        enableCaption: "Aggiunge una freccia alla barra dei menu. Fai clic per vedere tutte le icone della barra dei menu in un menu a discesa, raggruppate nelle tue categorie, poi fai clic su un’icona per usarla.",
        requiresMacOS27: "Richiede macOS 27 o versioni successive.",
        openDropdown: "Icone della barra dei menu",
        permissionNeeded: "Per elencare e aprire le icone delle altre app serve Accessibilità.",
        categoriesSection: "Categorie",
        categoriesCaption: "Dai un nome ai tuoi gruppi, come Lavoro o Media, poi scegli una categoria per ogni icona qui sotto.",
        categoryLabel: "Categoria",
        uncategorized: "Senza categoria",
        newCategory: "Nuova categoria",
        addCategory: "Aggiungi",
        deleteCategory: "Elimina categoria",
        iconsSection: "Icone",
        iconsCaption: "Tutte le icone presenti ora nella barra dei menu. Scegli dove compare ciascuna nel menu a discesa.",
        refresh: "Aggiorna",
        noIcons: "Nessuna icona trovata nella barra dei menu",
        openSettings: "Impostazioni del gestore della barra dei menu…"
    )
    static let ja = MenuBarManagerStrings(
        title: "メニューバーマネージャ",
        hubDescription: "メニューバーのすべてのアイコンを、カテゴリ別の1つのドロップダウンから開く",
        enableLabel: "アイコンのドロップダウンを表示",
        enableCaption: "メニューバーに矢印を追加します。クリックすると、メニューバーのすべてのアイコンがカテゴリ別に1つのドロップダウンに表示され、アイコンをクリックすると使えます。",
        requiresMacOS27: "macOS 27以降が必要です。",
        openDropdown: "メニューバーのアイコン",
        permissionNeeded: "ほかのアプリのアイコンを一覧表示して開くには、アクセシビリティの許可が必要です。",
        categoriesSection: "カテゴリ",
        categoriesCaption: "「仕事」や「メディア」など好きな名前のグループを作り、下で各アイコンのカテゴリを選びます。",
        categoryLabel: "カテゴリ",
        uncategorized: "カテゴリなし",
        newCategory: "新規カテゴリ",
        addCategory: "追加",
        deleteCategory: "カテゴリを削除",
        iconsSection: "アイコン",
        iconsCaption: "現在メニューバーにあるすべてのアイコンです。ドロップダウンでの表示先をそれぞれ選びます。",
        refresh: "更新",
        noIcons: "メニューバーのアイコンが見つかりません",
        openSettings: "メニューバーマネージャの設定…"
    )
    static let ko = MenuBarManagerStrings(
        title: "메뉴 막대 관리자",
        hubDescription: "메뉴 막대의 모든 아이콘을 카테고리별로 묶인 하나의 드롭다운에서 엽니다",
        enableLabel: "아이콘 드롭다운 보기",
        enableCaption: "메뉴 막대에 화살표를 추가합니다. 화살표를 클릭하면 메뉴 막대의 모든 아이콘이 카테고리별로 하나의 드롭다운에 표시되고, 아이콘을 클릭하면 사용할 수 있습니다.",
        requiresMacOS27: "macOS 27 이상이 필요합니다.",
        openDropdown: "메뉴 막대 아이콘",
        permissionNeeded: "다른 앱의 아이콘을 나열하고 열려면 손쉬운 사용 권한이 필요합니다.",
        categoriesSection: "카테고리",
        categoriesCaption: "업무나 미디어처럼 원하는 이름으로 그룹을 만든 다음, 아래에서 아이콘마다 카테고리를 선택하세요.",
        categoryLabel: "카테고리",
        uncategorized: "카테고리 없음",
        newCategory: "새 카테고리",
        addCategory: "추가",
        deleteCategory: "카테고리 삭제",
        iconsSection: "아이콘",
        iconsCaption: "지금 메뉴 막대에 있는 모든 아이콘입니다. 각 아이콘이 드롭다운의 어디에 표시될지 선택하세요.",
        refresh: "새로 고침",
        noIcons: "메뉴 막대 아이콘을 찾을 수 없습니다",
        openSettings: "메뉴 막대 관리자 설정…"
    )
    static let uk = MenuBarManagerStrings(
        title: "Менеджер смуги меню",
        hubDescription: "Відкривайте всі значки смуги меню з одного спадного списку з категоріями",
        enableLabel: "Показувати список значків",
        enableCaption: "Додає до смуги меню стрілку. Клацніть її, щоб побачити всі значки смуги меню в одному спадному списку, згруповані за вашими категоріями, і клацніть значок, щоб скористатися ним.",
        requiresMacOS27: "Потрібна macOS 27 або новіша.",
        openDropdown: "Значки смуги меню",
        permissionNeeded: "Щоб бачити й відкривати значки інших програм, потрібен дозвіл Доступності.",
        categoriesSection: "Категорії",
        categoriesCaption: "Створіть власні групи, наприклад «Робота» чи «Медіа», а потім виберіть категорію для кожного значка нижче.",
        categoryLabel: "Категорія",
        uncategorized: "Без категорії",
        newCategory: "Нова категорія",
        addCategory: "Додати",
        deleteCategory: "Видалити категорію",
        iconsSection: "Значки",
        iconsCaption: "Усі значки, що зараз є у смузі меню. Виберіть, де кожен з’явиться в списку.",
        refresh: "Оновити",
        noIcons: "Значків смуги меню не знайдено",
        openSettings: "Параметри менеджера смуги меню…"
    )
    static let zhHans = MenuBarManagerStrings(
        title: "菜单栏管理器",
        hubDescription: "从一个下拉菜单打开所有菜单栏图标，并按分类排列",
        enableLabel: "显示图标下拉菜单",
        enableCaption: "在菜单栏中添加一个箭头。点按它即可在一个下拉菜单中看到所有菜单栏图标，并按你的分类排列，点按其中的图标即可使用。",
        requiresMacOS27: "需要 macOS 27 或更高版本。",
        openDropdown: "菜单栏图标",
        permissionNeeded: "列出并打开其他 App 的图标需要辅助功能权限。",
        categoriesSection: "分类",
        categoriesCaption: "用你自己的名称创建分组，例如“工作”或“媒体”，然后在下方为每个图标选择分类。",
        categoryLabel: "分类",
        uncategorized: "未分类",
        newCategory: "新建分类",
        addCategory: "添加",
        deleteCategory: "删除分类",
        iconsSection: "图标",
        iconsCaption: "当前菜单栏中的所有图标。选择每个图标在下拉菜单中的位置。",
        refresh: "刷新",
        noIcons: "未找到菜单栏图标",
        openSettings: "菜单栏管理器设置…"
    )
    static let zhTW = MenuBarManagerStrings(
        title: "選單列管理器",
        hubDescription: "從一個下拉式選單打開所有選單列圖像，並依分類排列",
        enableLabel: "顯示圖像下拉式選單",
        enableCaption: "在選單列加入一個箭頭。按一下即可在一個下拉式選單中看到所有選單列圖像，並依你的分類排列，按一下其中的圖像即可使用。",
        requiresMacOS27: "需要 macOS 27 或以上版本。",
        openDropdown: "選單列圖像",
        permissionNeeded: "列出並打開其他 App 的圖像需要輔助使用權限。",
        categoriesSection: "分類",
        categoriesCaption: "用你自己的名稱建立分組，例如「工作」或「媒體」，然後在下方為每個圖像選擇分類。",
        categoryLabel: "分類",
        uncategorized: "未分類",
        newCategory: "新增分類",
        addCategory: "加入",
        deleteCategory: "刪除分類",
        iconsSection: "圖像",
        iconsCaption: "目前選單列中的所有圖像。選擇每個圖像在下拉式選單中的位置。",
        refresh: "重新整理",
        noIcons: "找不到選單列圖像",
        openSettings: "選單列管理器設定…"
    )
    static let zhHK = MenuBarManagerStrings(
        title: "選單列管理員",
        hubDescription: "從一個下拉式選單開啟所有選單列圖像，並按分類排列",
        enableLabel: "顯示圖像下拉式選單",
        enableCaption: "在選單列加入一個箭嘴。按一下即可在一個下拉式選單中看到所有選單列圖像，並按你的分類排列，按一下其中的圖像即可使用。",
        requiresMacOS27: "需要 macOS 27 或以上版本。",
        openDropdown: "選單列圖像",
        permissionNeeded: "列出並開啟其他 App 的圖像需要輔助使用權限。",
        categoriesSection: "分類",
        categoriesCaption: "用你自己的名稱建立分組，例如「工作」或「媒體」，然後在下方為每個圖像選擇分類。",
        categoryLabel: "分類",
        uncategorized: "未分類",
        newCategory: "新增分類",
        addCategory: "加入",
        deleteCategory: "刪除分類",
        iconsSection: "圖像",
        iconsCaption: "目前選單列中的所有圖像。選擇每個圖像在下拉式選單中的位置。",
        refresh: "重新整理",
        noIcons: "找不到選單列圖像",
        openSettings: "選單列管理員設定…"
    )
}
