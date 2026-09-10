-- Lesson chapters. The prose and the ordering are curated; the keymaps inside
-- each chapter come from the live inventory, so a chapter cannot list a map
-- that no longer exists or omit one that was just added.

local inventory = require('tutor.inventory')

local M = {}

-- Ordered from "used every second" outward to "used on demand".
M.CHAPTERS = {
  {
    key = 'core',
    title = 'Motions & the basics',
    blurb = 'j/k respect wrapped lines here (gj/gk), so long comments scroll the '
      .. 'way they look. Everything else builds on these.',
  },
  {
    key = 'files',
    title = 'Files, buffers & saving',
    blurb = 'Leader is <Space>. <leader>e opens mini.files, <leader>E opens it at '
      .. 'the current file. <leader>w saves; <C-s> saves from any mode.',
  },
  {
    key = 'pick',
    title = 'Fuzzy finding (mini.pick)',
    blurb = 'The <leader>f family is the fastest way anywhere. <leader>fg greps '
      .. 'live; <leader>fk lists every keymap -- the same table this tutor reads.',
  },
  {
    key = 'surround',
    title = 'Surround (mini.surround)',
    blurb = 'sa/sd/sr add, delete and replace delimiters. Motion-driven, so they '
      .. 'compose with iw, ip or a visual selection. Heavily drilled.',
  },
  {
    key = 'goto',
    title = 'Comment, splitjoin & goto',
    blurb = 'gcc toggles a line, gc takes a motion, gS splits or joins a '
      .. 'collection. These three replace a lot of manual editing.',
  },
  {
    key = 'code',
    title = 'Code actions & formatting',
    blurb = 'The <leader>c family plus <leader>sr. Formatting runs on save '
      .. 'unless you toggle it off with <leader>uf.',
  },
  {
    key = 'lsp',
    title = 'LSP navigation',
    blurb = 'gd, gr, K and friends are Lspsaga-backed. These are buffer-local -- '
      .. 'they exist only once a language server has attached.',
  },
  {
    key = 'windows',
    title = 'Windows & splits',
    blurb = '<C-hjkl> moves between windows, including out of a terminal. '
      .. '<leader>- and <leader>| split.',
  },
  {
    key = 'tabs',
    title = 'Tabs',
    blurb = 'The <leader><Tab> family. Useful for holding two unrelated layouts.',
  },
  {
    key = 'toggles',
    title = 'Toggles',
    blurb = 'The <leader>u family flips options: format-on-save, wrap, numbers, '
      .. 'and <leader>uc cycles the three colorschemes.',
  },
  {
    key = 'git',
    title = 'Git & blame',
    blurb = '<leader>gb toggles inline blame. It works in jj workspaces with no '
      .. '.git by shelling out to `jj file annotate`.',
  },
  {
    key = 'debug',
    title = 'Debugging (DAP)',
    blurb = 'The <leader>d family. DAP is lazy-loaded, so the first keypress '
      .. 'pays the startup cost.',
  },
  {
    key = 'tutor',
    title = 'This tutor',
    blurb = '<leader>td drills whatever you are slowest at. <leader>ts shows the '
      .. 'numbers. :Dojo drill <group> targets one family.',
  },
  {
    key = 'other',
    title = 'Everything else',
    blurb = 'Maps that do not fall into a family above. If this section grows, '
      .. 'tutor/inventory.lua wants a new group.',
  },
}

function M.chapters()
  local buckets = inventory.groups()
  local out = {}
  for _, chapter in ipairs(M.CHAPTERS) do
    local entries = buckets[chapter.key] or {}
    out[#out + 1] = {
      key = chapter.key,
      title = chapter.title,
      blurb = chapter.blurb,
      entries = entries,
      available = #entries > 0,
      -- An empty LSP chapter is not broken, just not yet reachable.
      unavailable_reason = (chapter.key == 'lsp' and #entries == 0)
        and 'Open a code file so a language server attaches, then reopen the tutor.'
        or nil,
    }
  end
  return out
end

function M.chapter(key)
  for _, c in ipairs(M.chapters()) do
    if c.key == key then return c end
  end
end

return M
