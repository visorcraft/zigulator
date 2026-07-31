const std = @import("std");

pub const Lang = enum { en, pt_br };

pub const Key = enum {
    app_title,
    menu_file,
    menu_edit,
    menu_view,
    menu_help,
    exit,
    copy,
    paste,
    simple,
    standard,
    scientific,
    history,
    graph,
    statistics,
    language,
    decimal_sep,
    about,
    about_text,
    error_div_zero,
    error_overflow,
    error_domain,
    error_invalid,
    add_function,
    x_min,
    x_max,
    dataset,
    count,
    sum,
    mean,
    stddev,
    clear_all,
    close,
};

pub fn tr(lang: Lang, key: Key) [:0]const u8 {
    return switch (lang) {
        .en => switch (key) {
            .app_title => "Zigulator",
            .menu_file => "File",
            .menu_edit => "Edit",
            .menu_view => "View",
            .menu_help => "Help",
            .exit => "Exit",
            .copy => "Copy",
            .paste => "Paste",
            .simple => "Simple",
            .standard => "Standard",
            .scientific => "Scientific",
            .history => "History",
            .graph => "Graph",
            .statistics => "Statistics",
            .language => "Language",
            .decimal_sep => "Decimal separator",
            .about => "About",
            .about_text => "A modern desktop calculator built with Zig and Dear ImGui.",
            .error_div_zero => "Cannot divide by zero",
            .error_overflow => "Overflow",
            .error_domain => "Invalid input for function",
            .error_invalid => "Invalid input",
            .add_function => "Add function",
            .x_min => "x min",
            .x_max => "x max",
            .dataset => "Dataset",
            .count => "Count",
            .sum => "Sum",
            .mean => "Mean",
            .stddev => "Std dev (s)",
            .clear_all => "Clear all",
            .close => "Close",
        },
        .pt_br => switch (key) {
            .app_title => "Zigulator",
            .menu_file => "Arquivo",
            .menu_edit => "Editar",
            .menu_view => "Exibir",
            .menu_help => "Ajuda",
            .exit => "Sair",
            .copy => "Copiar",
            .paste => "Colar",
            .simple => "Simples",
            .standard => "Padrão",
            .scientific => "Científica",
            .history => "Histórico",
            .graph => "Gráfico",
            .statistics => "Estatísticas",
            .language => "Idioma",
            .decimal_sep => "Separador decimal",
            .about => "Sobre",
            .about_text => "Uma calculadora desktop moderna feita com Zig e Dear ImGui.",
            .error_div_zero => "Não é possível dividir por zero",
            .error_overflow => "Estouro",
            .error_domain => "Entrada inválida para a função",
            .error_invalid => "Entrada inválida",
            .add_function => "Adicionar função",
            .x_min => "x mín",
            .x_max => "x máx",
            .dataset => "Conjunto de dados",
            .count => "Quantidade",
            .sum => "Soma",
            .mean => "Média",
            .stddev => "Desvio padrão (s)",
            .clear_all => "Limpar tudo",
            .close => "Fechar",
        },
    };
}

test "every key is translated in every language" {
    inline for (@typeInfo(Key).@"enum".fields) |f| {
        const key: Key = @enumFromInt(f.value);
        inline for (@typeInfo(Lang).@"enum".fields) |lf| {
            const lang: Lang = @enumFromInt(lf.value);
            try std.testing.expect(tr(lang, key).len > 0);
        }
    }
}

test "spot checks" {
    try std.testing.expectEqualStrings("File", tr(.en, .menu_file));
    try std.testing.expectEqualStrings("Arquivo", tr(.pt_br, .menu_file));
    try std.testing.expectEqualStrings("Sair", tr(.pt_br, .exit));
}
