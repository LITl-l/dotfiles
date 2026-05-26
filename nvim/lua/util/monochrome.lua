-- Monochrome theme engine.
-- Ported from https://github.com/anotherglitchinthematrix/monochrome
-- Variants live in nvim/colors/monochrome-*.lua and call M.apply().

local M = {}

local function hex_to_rgb(h)
  return tonumber(h:sub(2, 3), 16), tonumber(h:sub(4, 5), 16), tonumber(h:sub(6, 7), 16)
end

-- Linear-blend between bg and fg at ratio t∈[0,1], returning '#RRGGBB'.
local function blend_fn(bg_hex, fg_hex)
  local br, bg2, bb = hex_to_rgb(bg_hex)
  local fr, fg2, fb = hex_to_rgb(fg_hex)
  return function(t)
    local r = math.floor(br + (fr - br) * t + 0.5)
    local g = math.floor(bg2 + (fg2 - bg2) * t + 0.5)
    local b = math.floor(bb + (fb - bb) * t + 0.5)
    return string.format('#%02X%02X%02X', r, g, b)
  end
end

-- Build the full palette from (bg, fg). All UI tones are derived blends;
-- only accents (error/warning/diff) live outside the gray axis.
function M.palette(bg_hex, fg_hex, opts)
  opts = opts or {}
  local blend = blend_fn(bg_hex, fg_hex)
  return {
    blend = blend,
    bg       = blend(0.00),
    bg_alt   = blend(0.04),
    bg_soft  = blend(0.06),
    sel      = blend(0.12),
    border   = blend(0.18),
    mute3    = blend(0.30),
    mute2    = blend(0.45),
    mute1    = blend(0.60),
    text2    = blend(0.75),
    text1    = blend(0.88),
    fg       = blend(1.00),
    error    = opts.error   or '#B91C1C',
    warning  = opts.warning or '#B45309',
    add      = opts.add     or '#15803D',
    change   = opts.change  or '#1D4ED8',
    delete   = opts.delete  or '#B91C1C',
  }
end

function M.apply(name, p, background)
  vim.cmd('hi clear')
  if vim.fn.exists('syntax_on') then vim.cmd('syntax reset') end
  vim.o.background = background
  vim.g.colors_name = name

  local hi = function(group, spec) vim.api.nvim_set_hl(0, group, spec) end
  local blend = p.blend

  -- Editor surfaces ------------------------------------------------------
  hi('Normal',        { fg = p.fg,    bg = p.bg })
  hi('NormalNC',      { fg = p.fg,    bg = p.bg })
  hi('NormalFloat',   { fg = p.fg,    bg = p.bg_alt })
  hi('FloatBorder',   { fg = p.border, bg = p.bg_alt })
  hi('FloatTitle',    { fg = p.fg,    bg = p.bg_alt, bold = true })
  hi('WinSeparator',  { fg = p.border, bg = p.bg })
  hi('VertSplit',     { fg = p.border, bg = p.bg })
  hi('EndOfBuffer',   { fg = p.bg,    bg = p.bg })

  hi('LineNr',        { fg = p.mute2, bg = p.bg })
  hi('CursorLineNr',  { fg = p.fg,    bg = p.bg_soft, bold = true })
  hi('CursorLine',    { bg = p.bg_soft })
  hi('CursorColumn',  { bg = p.bg_soft })
  hi('ColorColumn',   { bg = p.bg_alt })
  hi('SignColumn',    { fg = p.mute2, bg = p.bg })
  hi('FoldColumn',    { fg = p.mute2, bg = p.bg })
  hi('Folded',        { fg = p.mute1, bg = p.bg_alt, italic = true })
  hi('Whitespace',    { fg = p.border })
  hi('NonText',       { fg = p.mute3 })
  hi('SpecialKey',    { fg = p.mute3 })
  hi('Conceal',       { fg = p.mute2, bg = p.bg })

  hi('Visual',        { bg = p.sel })
  hi('VisualNOS',     { bg = p.sel })
  hi('Search',        { fg = p.bg,    bg = p.text2 })
  hi('IncSearch',     { fg = p.bg,    bg = p.fg, bold = true })
  hi('CurSearch',     { fg = p.bg,    bg = p.fg, bold = true })
  hi('Substitute',    { fg = p.bg,    bg = p.text1 })
  hi('MatchParen',    { fg = p.fg,    bg = p.sel, bold = true })

  hi('StatusLine',    { fg = p.fg,    bg = p.bg_alt })
  hi('StatusLineNC',  { fg = p.mute1, bg = p.bg_alt })
  hi('TabLine',       { fg = p.mute1, bg = p.bg_alt })
  hi('TabLineSel',    { fg = p.fg,    bg = p.bg, bold = true })
  hi('TabLineFill',   { fg = p.mute1, bg = p.bg_alt })
  hi('WinBar',        { fg = p.text1, bg = p.bg, bold = true })
  hi('WinBarNC',      { fg = p.mute1, bg = p.bg })

  hi('Pmenu',         { fg = p.fg,    bg = p.bg_alt })
  hi('PmenuSel',      { fg = p.bg,    bg = p.fg, bold = true })
  hi('PmenuSbar',     { bg = p.bg_alt })
  hi('PmenuThumb',    { bg = p.border })
  hi('PmenuKind',     { fg = p.mute1, bg = p.bg_alt })
  hi('PmenuExtra',    { fg = p.mute1, bg = p.bg_alt })

  hi('Cursor',        { fg = p.bg, bg = p.fg })
  hi('TermCursor',    { fg = p.bg, bg = p.fg })
  hi('lCursor',       { fg = p.bg, bg = p.fg })
  hi('QuickFixLine',  { bg = p.sel, bold = true })

  hi('Title',         { fg = p.fg,    bold = true })
  hi('Directory',     { fg = p.text1, bold = true })
  hi('Question',      { fg = p.fg })
  hi('ModeMsg',       { fg = p.fg,    bold = true })
  hi('MoreMsg',       { fg = p.fg })
  hi('MsgArea',       { fg = p.fg,    bg = p.bg })
  hi('ErrorMsg',      { fg = p.error, bold = true })
  hi('WarningMsg',    { fg = p.warning, bold = true })

  -- Spell ----------------------------------------------------------------
  hi('SpellBad',      { sp = p.error,   undercurl = true })
  hi('SpellCap',      { sp = p.warning, undercurl = true })
  hi('SpellLocal',    { sp = p.mute1,   undercurl = true })
  hi('SpellRare',     { sp = p.mute1,   undercurl = true })

  -- Syntax (legacy groups) ----------------------------------------------
  hi('Comment',       { fg = p.mute2, italic = true })
  hi('Constant',      { fg = p.fg })
  hi('String',        { fg = p.text2 })
  hi('Character',     { fg = p.text2 })
  hi('Number',        { fg = p.fg,    bold = true })
  hi('Float',         { fg = p.fg,    bold = true })
  hi('Boolean',       { fg = p.fg,    bold = true })

  hi('Identifier',    { fg = p.fg })
  hi('Function',      { fg = p.fg,    bold = true })

  hi('Statement',     { fg = p.text1, bold = true })
  hi('Conditional',   { fg = p.text1, bold = true })
  hi('Repeat',        { fg = p.text1, bold = true })
  hi('Label',         { fg = p.text1, bold = true })
  hi('Operator',      { fg = p.mute1 })
  hi('Keyword',       { fg = p.text1, bold = true })
  hi('Exception',     { fg = p.text1, bold = true })

  hi('PreProc',       { fg = p.mute1 })
  hi('Include',       { fg = p.text1, bold = true })
  hi('Define',        { fg = p.text1, bold = true })
  hi('Macro',         { fg = p.text1 })
  hi('PreCondit',     { fg = p.mute1 })

  hi('Type',          { fg = p.text1 })
  hi('StorageClass',  { fg = p.text1, bold = true })
  hi('Structure',     { fg = p.text1 })
  hi('Typedef',       { fg = p.text1 })

  hi('Special',       { fg = p.mute1 })
  hi('SpecialChar',   { fg = p.mute1 })
  hi('Tag',           { fg = p.text2 })
  hi('Delimiter',     { fg = p.mute1 })
  hi('SpecialComment',{ fg = p.mute2, italic = true })
  hi('Debug',         { fg = p.mute1 })
  hi('Underlined',    { fg = p.fg,    underline = true })
  hi('Italic',        { italic = true })
  hi('Bold',          { bold = true })
  hi('Todo',          { fg = p.fg,    bg = p.sel, bold = true })

  -- Diffs ----------------------------------------------------------------
  hi('DiffAdd',       { fg = p.fg,    bg = blend(0.10) })
  hi('DiffChange',    { fg = p.fg,    bg = blend(0.06) })
  hi('DiffDelete',    { fg = p.mute1, bg = blend(0.14) })
  hi('DiffText',      { fg = p.fg,    bg = blend(0.18), bold = true })
  hi('diffAdded',     { fg = p.add })
  hi('diffRemoved',   { fg = p.delete })
  hi('diffChanged',   { fg = p.change })

  -- Diagnostics ---------------------------------------------------------
  hi('DiagnosticError',          { fg = p.error })
  hi('DiagnosticWarn',           { fg = p.warning })
  hi('DiagnosticInfo',           { fg = p.text2 })
  hi('DiagnosticHint',           { fg = p.mute1 })
  hi('DiagnosticOk',             { fg = p.add })
  hi('DiagnosticUnderlineError', { sp = p.error,   undercurl = true })
  hi('DiagnosticUnderlineWarn',  { sp = p.warning, undercurl = true })
  hi('DiagnosticUnderlineInfo',  { sp = p.text2,   undercurl = true })
  hi('DiagnosticUnderlineHint',  { sp = p.mute1,   undercurl = true })
  hi('DiagnosticVirtualTextError', { fg = p.error,   bg = p.bg_alt })
  hi('DiagnosticVirtualTextWarn',  { fg = p.warning, bg = p.bg_alt })
  hi('DiagnosticVirtualTextInfo',  { fg = p.text2,   bg = p.bg_alt })
  hi('DiagnosticVirtualTextHint',  { fg = p.mute1,   bg = p.bg_alt })

  -- LSP ------------------------------------------------------------------
  hi('LspReferenceText',  { bg = p.sel })
  hi('LspReferenceRead',  { bg = p.sel })
  hi('LspReferenceWrite', { bg = p.sel, bold = true })
  hi('LspSignatureActiveParameter', { fg = p.fg, bold = true })
  hi('LspInlayHint',      { fg = p.mute2, bg = p.bg_alt, italic = true })

  -- Treesitter ----------------------------------------------------------
  hi('@comment',          { link = 'Comment' })
  hi('@comment.todo',     { fg = p.fg, bg = p.sel, bold = true })
  hi('@comment.note',     { fg = p.text2, italic = true })
  hi('@comment.warning',  { fg = p.warning })
  hi('@comment.error',    { fg = p.error })

  hi('@keyword',          { fg = p.text1, bold = true })
  hi('@keyword.function', { fg = p.text1, bold = true })
  hi('@keyword.return',   { fg = p.text1, bold = true })
  hi('@keyword.operator', { fg = p.text1, bold = true })
  hi('@conditional',      { link = 'Conditional' })
  hi('@repeat',           { link = 'Repeat' })
  hi('@exception',        { link = 'Exception' })

  hi('@function',         { fg = p.fg, bold = true })
  hi('@function.call',    { fg = p.fg })
  hi('@function.builtin', { fg = p.fg, bold = true })
  hi('@function.macro',   { fg = p.text1, bold = true })
  hi('@method',           { fg = p.fg, bold = true })
  hi('@method.call',      { fg = p.fg })
  hi('@constructor',      { fg = p.fg, bold = true })

  hi('@variable',         { fg = p.fg })
  hi('@variable.builtin', { fg = p.text1, italic = true })
  hi('@variable.parameter', { fg = p.fg, italic = true })
  hi('@variable.member',  { fg = p.text2 })
  hi('@parameter',        { fg = p.fg, italic = true })
  hi('@field',            { fg = p.text2 })
  hi('@property',         { fg = p.text2 })

  hi('@string',           { fg = p.text2 })
  hi('@string.escape',    { fg = p.mute1, bold = true })
  hi('@string.special',   { fg = p.mute1 })
  hi('@string.regex',     { fg = p.text2, italic = true })
  hi('@character',        { fg = p.text2 })
  hi('@number',           { fg = p.fg, bold = true })
  hi('@boolean',          { fg = p.fg, bold = true })
  hi('@float',            { fg = p.fg, bold = true })
  hi('@constant',         { fg = p.fg })
  hi('@constant.builtin', { fg = p.fg, bold = true })
  hi('@constant.macro',   { fg = p.text1, bold = true })

  hi('@type',             { fg = p.text1 })
  hi('@type.builtin',     { fg = p.text1, italic = true })
  hi('@type.definition',  { fg = p.text1, bold = true })
  hi('@attribute',        { fg = p.mute1 })
  hi('@operator',         { fg = p.mute1 })
  hi('@punctuation',      { fg = p.mute1 })
  hi('@punctuation.delimiter', { fg = p.mute1 })
  hi('@punctuation.bracket',   { fg = p.mute1 })
  hi('@punctuation.special',   { fg = p.mute1 })

  hi('@tag',              { fg = p.text1, bold = true })
  hi('@tag.attribute',    { fg = p.text2, italic = true })
  hi('@tag.delimiter',    { fg = p.mute1 })

  hi('@markup.heading',   { fg = p.fg, bold = true })
  hi('@markup.strong',    { fg = p.fg, bold = true })
  hi('@markup.italic',    { fg = p.fg, italic = true })
  hi('@markup.strikethrough', { fg = p.mute1, strikethrough = true })
  hi('@markup.underline', { underline = true })
  hi('@markup.link',      { fg = p.text2, underline = true })
  hi('@markup.link.url',  { fg = p.mute1, underline = true })
  hi('@markup.raw',       { fg = p.text2, bg = p.bg_alt })
  hi('@markup.list',      { fg = p.mute1 })
  hi('@markup.quote',     { fg = p.mute1, italic = true })

  hi('@diff.plus',        { fg = p.add })
  hi('@diff.minus',       { fg = p.delete })
  hi('@diff.delta',       { fg = p.change })

  -- mini.nvim -----------------------------------------------------------
  hi('MiniStatuslineModeNormal',  { fg = p.bg, bg = p.fg, bold = true })
  hi('MiniStatuslineModeInsert',  { fg = p.bg, bg = p.text1, bold = true })
  hi('MiniStatuslineModeVisual',  { fg = p.bg, bg = p.text2, bold = true })
  hi('MiniStatuslineModeReplace', { fg = p.bg, bg = p.text1, bold = true })
  hi('MiniStatuslineModeCommand', { fg = p.bg, bg = p.mute1, bold = true })
  hi('MiniStatuslineModeOther',   { fg = p.bg, bg = p.mute1, bold = true })
  hi('MiniStatuslineDevinfo',     { fg = p.fg, bg = p.bg_alt })
  hi('MiniStatuslineFilename',    { fg = p.mute1, bg = p.bg_alt })
  hi('MiniStatuslineFileinfo',    { fg = p.fg, bg = p.bg_alt })
  hi('MiniStatuslineInactive',    { fg = p.mute1, bg = p.bg_alt })

  hi('MiniTablineCurrent',        { fg = p.fg, bg = p.bg, bold = true })
  hi('MiniTablineVisible',        { fg = p.text1, bg = p.bg_alt })
  hi('MiniTablineHidden',         { fg = p.mute1, bg = p.bg_alt })
  hi('MiniTablineModifiedCurrent',{ fg = p.fg, bg = p.bg, italic = true, bold = true })
  hi('MiniTablineModifiedVisible',{ fg = p.text1, bg = p.bg_alt, italic = true })
  hi('MiniTablineModifiedHidden', { fg = p.mute1, bg = p.bg_alt, italic = true })
  hi('MiniTablineFill',           { bg = p.bg_alt })

  hi('MiniHipatternsFixme', { fg = p.bg, bg = p.error, bold = true })
  hi('MiniHipatternsHack',  { fg = p.bg, bg = p.warning, bold = true })
  hi('MiniHipatternsTodo',  { fg = p.bg, bg = p.text1, bold = true })
  hi('MiniHipatternsNote',  { fg = p.bg, bg = p.mute1, bold = true })

  hi('MiniCursorword',      { bg = p.sel })
  hi('MiniCursorwordCurrent', { bg = p.sel })

  hi('MiniFilesNormal',     { fg = p.fg, bg = p.bg_alt })
  hi('MiniFilesBorder',     { fg = p.border, bg = p.bg_alt })
  hi('MiniFilesTitle',      { fg = p.mute1, bg = p.bg_alt })
  hi('MiniFilesTitleFocused', { fg = p.fg, bg = p.bg_alt, bold = true })
  hi('MiniFilesDirectory',  { fg = p.text1, bold = true })
  hi('MiniFilesFile',       { fg = p.fg })
  hi('MiniFilesCursorLine', { bg = p.sel })

  hi('MiniIndentscopeSymbol', { fg = p.border })
  hi('MiniIndentscopePrefix', { nocombine = true })

  hi('MiniPickNormal',      { fg = p.fg, bg = p.bg_alt })
  hi('MiniPickBorder',      { fg = p.border, bg = p.bg_alt })
  hi('MiniPickPrompt',      { fg = p.fg, bg = p.bg_alt, bold = true })
  hi('MiniPickMatchCurrent',{ bg = p.sel, bold = true })
  hi('MiniPickMatchMarked', { fg = p.fg, bg = p.bg_soft })
  hi('MiniPickHeader',      { fg = p.mute1, bg = p.bg_alt })

  hi('MiniStarterCurrent',  { bg = p.sel })
  hi('MiniStarterHeader',   { fg = p.text1, bold = true })
  hi('MiniStarterFooter',   { fg = p.mute1, italic = true })
  hi('MiniStarterItem',     { fg = p.fg })
  hi('MiniStarterItemBullet', { fg = p.mute1 })
  hi('MiniStarterItemPrefix', { fg = p.text1, bold = true })
  hi('MiniStarterSection',  { fg = p.text2, bold = true })
  hi('MiniStarterQuery',    { fg = p.fg, bg = p.sel })

  hi('MiniDiffSignAdd',     { fg = p.add })
  hi('MiniDiffSignChange',  { fg = p.change })
  hi('MiniDiffSignDelete',  { fg = p.delete })
  hi('MiniDiffOverAdd',     { bg = blend(0.10) })
  hi('MiniDiffOverChange',  { bg = blend(0.08) })
  hi('MiniDiffOverDelete',  { bg = blend(0.14) })

  hi('MiniTrailspace',      { bg = p.warning })

  -- Git / lspsaga / which-key -------------------------------------------
  hi('GitSignsAdd',    { fg = p.add,    bg = p.bg })
  hi('GitSignsChange', { fg = p.change, bg = p.bg })
  hi('GitSignsDelete', { fg = p.delete, bg = p.bg })

  hi('LspsagaNormal',     { fg = p.fg, bg = p.bg_alt })
  hi('LspsagaBorder',     { fg = p.border, bg = p.bg_alt })
  hi('LspsagaTitle',      { fg = p.fg, bold = true })
  hi('LspsagaActionTxt',  { fg = p.fg })
  hi('LspsagaActionFg',   { fg = p.text2 })

  hi('WhichKey',          { fg = p.fg, bold = true })
  hi('WhichKeyGroup',     { fg = p.text1 })
  hi('WhichKeyDesc',      { fg = p.fg })
  hi('WhichKeySeparator', { fg = p.mute1 })
  hi('WhichKeyFloat',     { bg = p.bg_alt })
  hi('WhichKeyBorder',    { fg = p.border, bg = p.bg_alt })
  hi('WhichKeyValue',     { fg = p.mute1 })

  -- Terminal colors (ANSI 0-15) -----------------------------------------
  -- 0 = "ink" (darkest available), 15 = "paper" (lightest).
  local ink   = background == 'dark' and p.bg or p.fg
  local paper = background == 'dark' and p.fg or p.bg
  vim.g.terminal_color_0  = ink
  vim.g.terminal_color_1  = p.error
  vim.g.terminal_color_2  = p.add
  vim.g.terminal_color_3  = p.warning
  vim.g.terminal_color_4  = p.change
  vim.g.terminal_color_5  = p.text1
  vim.g.terminal_color_6  = p.text2
  vim.g.terminal_color_7  = p.mute1
  vim.g.terminal_color_8  = p.mute2
  vim.g.terminal_color_9  = p.error
  vim.g.terminal_color_10 = p.add
  vim.g.terminal_color_11 = p.warning
  vim.g.terminal_color_12 = p.change
  vim.g.terminal_color_13 = p.text1
  vim.g.terminal_color_14 = p.text2
  vim.g.terminal_color_15 = paper
end

return M
