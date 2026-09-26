package dev.omarchyphone.launcher

import androidx.compose.ui.graphics.Color

// Omarchy's themes, from each theme's colors.toml in the Omarchy repository
// (themes/<name>/colors.toml): the four colours the launcher draws with.
// Generated; regenerate rather than edit by hand.
data class OmarchyTheme(
    val id: String,
    val name: String,
    val dark: Boolean,
    val background: Color,
    val foreground: Color,
    val accent: Color,
    val urgent: Color,
)

val omarchyThemes: List<OmarchyTheme> = listOf(
    OmarchyTheme("catppuccin", "Catppuccin", dark = true, background = Color(0xFF1E1E2E), foreground = Color(0xFFCDD6F4), accent = Color(0xFF89B4FA), urgent = Color(0xFFF38BA8)),
    OmarchyTheme("catppuccin-latte", "Catppuccin Latte", dark = false, background = Color(0xFFEFF1F5), foreground = Color(0xFF4C4F69), accent = Color(0xFF1E66F5), urgent = Color(0xFFD20F39)),
    OmarchyTheme("ethereal", "Ethereal", dark = true, background = Color(0xFF060B1E), foreground = Color(0xFFFFCEAD), accent = Color(0xFF7D82D9), urgent = Color(0xFFED5B5A)),
    OmarchyTheme("everforest", "Everforest", dark = true, background = Color(0xFF2D353B), foreground = Color(0xFFD3C6AA), accent = Color(0xFF7FBBB3), urgent = Color(0xFFE67E80)),
    OmarchyTheme("flexoki-light", "Flexoki Light", dark = false, background = Color(0xFFFFFCF0), foreground = Color(0xFF100F0F), accent = Color(0xFF205EA6), urgent = Color(0xFFD14D41)),
    OmarchyTheme("gruvbox", "Gruvbox", dark = true, background = Color(0xFF282828), foreground = Color(0xFFD4BE98), accent = Color(0xFF7DAEA3), urgent = Color(0xFFEA6962)),
    OmarchyTheme("hackerman", "Hackerman", dark = true, background = Color(0xFF0B0C16), foreground = Color(0xFFDDF7FF), accent = Color(0xFF82FB9C), urgent = Color(0xFF50F872)),
    OmarchyTheme("kanagawa", "Kanagawa", dark = true, background = Color(0xFF1F1F28), foreground = Color(0xFFDCD7BA), accent = Color(0xFFDCD7BA), urgent = Color(0xFFC34043)),
    OmarchyTheme("last-horizon", "Last Horizon", dark = true, background = Color(0xFF0C0B0C), foreground = Color(0xFFFAFCFB), accent = Color(0xFFB59790), urgent = Color(0xFFC38B7B)),
    OmarchyTheme("lumon", "Lumon", dark = true, background = Color(0xFF16242D), foreground = Color(0xFFD6E2EE), accent = Color(0xFF8BC9EB), urgent = Color(0xFF4D86B0)),
    OmarchyTheme("lupine", "Lupine", dark = false, background = Color(0xFFFAFAFA), foreground = Color(0xFF212121), accent = Color(0xFF3264EB), urgent = Color(0xFFC900C4)),
    OmarchyTheme("matte-black", "Matte Black", dark = true, background = Color(0xFF121212), foreground = Color(0xFFBEBEBE), accent = Color(0xFFE68E0D), urgent = Color(0xFFD35F5F)),
    OmarchyTheme("miasma", "Miasma", dark = true, background = Color(0xFF222222), foreground = Color(0xFFC2C2B0), accent = Color(0xFF78824B), urgent = Color(0xFF685742)),
    OmarchyTheme("nord", "Nord", dark = true, background = Color(0xFF2E3440), foreground = Color(0xFFD8DEE9), accent = Color(0xFF81A1C1), urgent = Color(0xFFBF616A)),
    OmarchyTheme("osaka-jade", "Osaka Jade", dark = true, background = Color(0xFF111C18), foreground = Color(0xFFC1C497), accent = Color(0xFF509475), urgent = Color(0xFFFF5345)),
    OmarchyTheme("retro-82", "Retro 82", dark = true, background = Color(0xFF05182E), foreground = Color(0xFFF6DCAC), accent = Color(0xFFFAA968), urgent = Color(0xFFF85525)),
    OmarchyTheme("ristretto", "Ristretto", dark = true, background = Color(0xFF2C2525), foreground = Color(0xFFE6D9DB), accent = Color(0xFFF38D70), urgent = Color(0xFFFD6883)),
    OmarchyTheme("rose-pine", "Rose Pine", dark = false, background = Color(0xFFFAF4ED), foreground = Color(0xFF575279), accent = Color(0xFF56949F), urgent = Color(0xFFB4637A)),
    OmarchyTheme("solitude", "Solitude", dark = true, background = Color(0xFF101315), foreground = Color(0xFFCACCCC), accent = Color(0xFF798186), urgent = Color(0xFF565D60)),
    OmarchyTheme("tokyo-night", "Tokyo Night", dark = true, background = Color(0xFF1A1B26), foreground = Color(0xFFA9B1D6), accent = Color(0xFF7AA2F7), urgent = Color(0xFFF7768E)),
    OmarchyTheme("vantablack", "Vantablack", dark = true, background = Color(0xFF000000), foreground = Color(0xFFFFFFFF), accent = Color(0xFF8D8D8D), urgent = Color(0xFFA4A4A4)),
    OmarchyTheme("white", "White", dark = false, background = Color(0xFFFFFFFF), foreground = Color(0xFF000000), accent = Color(0xFF6E6E6E), urgent = Color(0xFF2A2A2A)),
)

fun themeById(id: String?): OmarchyTheme =
    omarchyThemes.firstOrNull { it.id == id } ?: omarchyThemes.first { it.id == "tokyo-night" }
