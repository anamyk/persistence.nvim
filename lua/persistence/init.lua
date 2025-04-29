local Config = require("persistence.config")

local uv = vim.uv or vim.loop

local M = {}
M._active = false

local e = vim.fn.fnameescape

---@param opts? {branch?: boolean, autosave?: boolean}
function M.current(opts)
  opts = opts or {}
  local name = vim.fn.getcwd():gsub("[\\/:]+", "%%")

  if Config.options.branch and opts.branch ~= false then
    local branch = M.branch()
    if branch and branch ~= "main" and branch ~= "master" then
      name = name .. "%%" .. branch:gsub("[\\/:]+", "%%")
    end
  end

  local base_path = Config.options.dir .. name

  if opts.autosave then
    -- -- Save into autosave/ folder with timestamp
    -- local autosave_dir = Config.options.dir .. "autosave/"
    -- vim.fn.mkdir(autosave_dir, "p") -- ensure folder exists
    --
    -- -- local timestamp = os.date("%Y-%m-%d_%H-%M-%S")
    -- -- return autosave_dir .. name:match("[^/]+$") .. ".autosave." .. timestamp .. ".vim"
    -- return autosave_dir .. name:match("[^/]+$") .. ".vim"
    return base_path .. ".vim"
  else
    return base_path .. ".vim"
  end
end

------@param opts? {branch?: boolean}
---function M.current(opts)
---  opts = opts or {}
---  local name = vim.fn.getcwd():gsub("[\\/:]+", "%%")
---  if Config.options.branch and opts.branch ~= false then
---    local branch = M.branch()
---    if branch and branch ~= "main" and branch ~= "master" then
---      name = name .. "%%" .. branch:gsub("[\\/:]+", "%%")
---    end
---  end
---  return Config.options.dir .. name .. ".vim"
---end

function M.setup(opts)
  Config.setup(opts)
  -- M.start()

  -- Intercept quit commands
  M.setup_quit_save_abbreviations()

  -- Setup window close detection
  -- M.setup_win_closed_detection()
end

function M.fire(event)
  vim.api.nvim_exec_autocmds("User", {
    pattern = "Persistence" .. event,
  })
end

-- Check if a session is active
function M.active()
  return M._active
end

-- is this func still relevant? no
-- function M.start()
--   M._active = true
--   vim.api.nvim_create_autocmd("VimLeavePre", {
--     group = vim.api.nvim_create_augroup("persistence", { clear = true }),
--     callback = function()
--       M.fire("SavePre")
--
--       if Config.options.need > 0 then
--         local bufs = vim.tbl_filter(function(b)
--           if vim.bo[b].buftype ~= "" or vim.tbl_contains({ "gitcommit", "gitrebase", "jj" }, vim.bo[b].filetype) then
--             return false
--           end
--           return vim.api.nvim_buf_get_name(b) ~= ""
--         end, vim.api.nvim_list_bufs())
--         if #bufs < Config.options.need then
--           return
--         end
--       end
--
--       -- M.save()
--       M.fire("SavePost")
--     end,
--   })
-- end

function M.stop()
  M._active = false
  pcall(vim.api.nvim_del_augroup_by_name, "persistence")
end

function M.save()
  vim.cmd("mks! " .. e(M.current()))
end

-- @param session_filename string
-- function M.load(session_filename)
--   if not session_filename then
--     print("⚡ No session filename given")
--     return
--   end
--
--   local session_path = vim.fn.stdpath("state") .. "/sessions/" .. session_filename
--
--   if vim.fn.filereadable(session_path) == 0 then
--     print("⚡ Session file does not exist: " .. session_path)
--     return
--   end
--
--   -- 🧹 Clean up current state
--   vim.cmd("tabonly")
--   vim.cmd("only")
--   vim.cmd("silent! bufdo bwipeout!")
--   vim.cmd("enew")
--
--   -- Parse project path
--   local filename = vim.fn.fnamemodify(session_filename, ":t")
--   local project_part = filename:match("^(.-)%.%d%d%d%d%-%d%d%-%d%d_%d%d%-%d%d%-%d%d%.vim$")
--     or filename:gsub("%.vim$", "")
--   local project_dir = "/" .. project_part:gsub("%%", "/")
--
--   if vim.fn.isdirectory(project_dir) == 1 then
--     vim.cmd("cd " .. vim.fn.fnameescape(project_dir))
--     print("📂 Changed directory to: " .. project_dir)
--   else
--     print("⚡ Warning: Project directory does not exist: " .. project_dir)
--   end
--
--   -- Load session
--   vim.cmd("silent! source " .. vim.fn.fnameescape(session_path))
--   print("✅ Loaded session: " .. session_path)
-- end

---@param session_path string
function M.load(session_path)
  if not session_path or vim.fn.filereadable(session_path) == 0 then
    print("⚡ Session file does not exist: " .. (session_path or ""))
    return
  end

  -- 🧹 Clean up current state
  vim.cmd("tabonly")
  vim.cmd("only")
  vim.cmd("silent! bufdo bwipeout!")
  vim.cmd("enew")

  -- 📂 Extract project from filename
  local filename = vim.fn.fnamemodify(session_path, ":t")
  local project_part = filename:gsub("%.vim$", "")
  local project_dir = "/" .. project_part:gsub("%%", "/")

  -- 📂 Try to cd into project
  if vim.fn.isdirectory(project_dir) == 1 then
    vim.cmd("cd " .. vim.fn.fnameescape(project_dir))
    print("📂 Changed directory to: " .. project_dir)
  else
    print("⚡ Warning: Project directory does not exist: " .. project_dir)
  end

  -- 📜 Actually load session
  vim.cmd("silent! source " .. vim.fn.fnameescape(session_path))
  print("✅ Loaded session from " .. session_path)

  -- 🌟 Save for prefill later
  M._last_session_loaded = project_part
end

------@param session_path string
---function M.load(session_path)
---  if not session_path or vim.fn.filereadable(session_path) == 0 then
---    print("⚡ Session file does not exist: " .. (session_path or ""))
---    return
---  end
---
---  -- 🧹 Clean up current state
---  vim.cmd("tabonly")
---  vim.cmd("only")
---  vim.cmd("silent! bufdo bwipeout!")
---  vim.cmd("enew")
---
---  -- Extract project from filename
---  local filename = vim.fn.fnamemodify(session_path, ":t")
---  local project_part = filename:match("^(.-)%.%d%d%d%d%-%d%d%-%d%d_%d%d%-%d%d%-%d%d%.vim$")
---    or filename:gsub("%.vim$", "")
---  local project_dir = "/" .. project_part:gsub("%%", "/")
---
---  if vim.fn.isdirectory(project_dir) == 1 then
---    vim.cmd("cd " .. vim.fn.fnameescape(project_dir))
---    print("📂 Changed directory to: " .. project_dir)
---  else
---    print("⚡ Warning: Project directory does not exist: " .. project_dir)
---  end
---
---  -- Actually load the session
---  vim.cmd("silent! source " .. e(session_path))
---  print("✅ Loaded session from " .. session_path)
---end

-- @param opts? { last?: boolean }
-- function M.load(opts)
--   opts = opts or {}
--   ---@type string
--   local file
--   if opts.last then
--     file = M.last()
--   else
--     file = M.current()
--     if vim.fn.filereadable(file) == 0 then
--       file = M.current({ branch = false })
--     end
--   end
--   if file and vim.fn.filereadable(file) ~= 0 then
--     M.fire("LoadPre")
--     vim.cmd("silent! source " .. e(file))
--     M.fire("LoadPost")
--   end
-- end

---@return string[]
function M.list()
  local sessions = vim.fn.glob(Config.options.dir .. "*.vim*", true, true)
  table.sort(sessions, function(a, b)
    return uv.fs_stat(a).mtime.sec > uv.fs_stat(b).mtime.sec
  end)
  return sessions
end
-- function M.list()
--   local sessions = vim.fn.glob(Config.options.dir .. "*.vim", true, true)
--   table.sort(sessions, function(a, b)
--     return uv.fs_stat(a).mtime.sec > uv.fs_stat(b).mtime.sec
--   end)
--   return sessions
-- end

function M.last()
  return M.list()[1]
end

-- function M.select()
--   ---@type { session: string, dir: string, branch?: string }[]
--   local items = {}
--   local have = {} ---@type table<string, boolean>
--   for _, session in ipairs(M.list()) do
--     if uv.fs_stat(session) then
--       local file = session:sub(#Config.options.dir + 1, -5)
--       -- local dir, branch = unpack(vim.split(file, "%%", { plain = true }))
--       local project_part = file:match("^(.-)%.%d%d%d%d%-%d%d%-%d%d_%d%d%-%d%d%-%d%d$")
--       if not project_part then
--         -- fallback: no timestamp, normal behavior
--         project_part = file
--       end
--       local dir, branch = unpack(vim.split(project_part, "%%", { plain = true }))
--
--       dir = dir:gsub("%%", "/")
--       if jit.os:find("Windows") then
--         dir = dir:gsub("^(%w)/", "%1:/")
--       end
--       if not have[dir] then
--         have[dir] = true
--         items[#items + 1] = { session = session, dir = dir, branch = branch }
--       end
--     end
--   end
--
--

function M.select()
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  local show_autosaves = false

  -- local function is_autosave_session(session_path)
  --   return session_path:find("/autosave/") ~= nil
  -- end
  local function is_autosave_session(session_path)
    local filename = vim.fn.fnamemodify(session_path, ":t")
    return filename:find("%%") ~= nil
  end

  local function get_sessions()
    local items = {}
    for _, session in ipairs(require("persistence").list()) do
      if uv.fs_stat(session) then
        local autosave = is_autosave_session(session)
        if show_autosaves or not autosave then
          local file = vim.fn.fnamemodify(session, ":t:r") -- filename without extension
          local project_part = file

          local dir
          if project_part:find("%%") then
            dir = project_part:gsub("%%", "/")
          end

          items[#items + 1] = { session = session, dir = dir, is_autosave = autosave }
        end
      end
    end
    return items
  end
  -- local function get_sessions()
  --   local items = {}
  --   for _, session in ipairs(require("persistence").list()) do
  --     if uv.fs_stat(session) then
  --       local is_autosave = session:find("/autosave/")
  --       if show_autosaves or not is_autosave then
  --         local file = session:sub(#Config.options.dir + 1, -5)
  --
  --         local project_part = file:match("^(.-)%.%d%d%d%d%-%d%d%-%d%d_%d%d%-%d%d%-%d%d$")
  --         if not project_part then
  --           project_part = file
  --         end
  --
  --         local dir
  --         if project_part:find("%%") then
  --           dir = project_part:gsub("%%", "/")
  --         end
  --
  --         items[#items + 1] = { session = session, dir = dir, is_autosave = is_autosave }
  --       end
  --     end
  --   end
  --   return items
  -- end

  local function create_picker()
    pickers
      .new({}, {
        -- prompt_title = show_autosaves and "Select session (autosaves visible)" or "Select session",
        prompt_title = show_autosaves and "Select session [+autosaves]" or "Select session",
        finder = finders.new_table({
          results = get_sessions(),
          entry_maker = function(item)
            return {
              value = item, -- <-- 🛠 full item (session + dir info)
              display = function(entry)
                local prefix = entry.value.is_autosave and "autosave: 💾 " or "project:  🚀 "
                -- local prefix = entry.value.is_autosave and "🚀 " or "📂 "
                local name = entry.value.dir and vim.fn.fnamemodify(entry.value.dir, ":p:~")
                  or vim.fn.fnamemodify(entry.value.session, ":t:r")
                return prefix .. name
              end,
              ordinal = item.dir or item.session,
            }
          end,
        }),
        sorter = conf.generic_sorter({}),
        attach_mappings = function(prompt_bufnr, map)
          local function open_session()
            local entry = action_state.get_selected_entry()
            if not entry then
              return
            end
            local item = entry.value

            actions.close(prompt_bufnr)

            vim.schedule(function()
              if item.dir and vim.fn.isdirectory(item.dir) == 1 then
                vim.fn.chdir(item.dir)
                print("📂 Changed directory to: " .. item.dir)
              end
              require("persistence").load(item.session)
            end)
          end

          map("i", "<CR>", open_session)
          map("n", "<CR>", open_session)

          -- 🌀 Toggle autosave visibility
          map("i", "<C-a>", function()
            show_autosaves = not show_autosaves
            actions.close(prompt_bufnr)
            vim.schedule(function()
              create_picker()
            end)
          end)

          map("n", "<C-a>", function()
            show_autosaves = not show_autosaves
            actions.close(prompt_bufnr)
            vim.schedule(function()
              create_picker()
            end)
          end)

          return true

          -- attach_mappings = function(prompt_bufnr, map)
          --   local function open_session()
          --     local entry = action_state.get_selected_entry()
          --     if not entry then
          --       return
          --     end
          --     local item = entry.value
          --     if item.dir and vim.fn.isdirectory(item.dir) == 1 then
          --       vim.fn.chdir(item.dir)
          --       print("📂 Changed directory to: " .. item.dir)
          --     end
          --     -- require("persistence").load(item.session) -- ✅ load session correctly
          --     -- actions.close(prompt_bufnr)
          --     actions.close(prompt_bufnr)
          --     vim.schedule(function()
          --       require("persistence").load(item.session)
          --     end)
          --   end
          --
          --   map("i", "<CR>", open_session)
          --   map("n", "<CR>", open_session)
          --
          --   -- 🌀 Toggle autosave visibility
          --   map("i", "<C-a>", function()
          --     show_autosaves = not show_autosaves
          --     actions.close(prompt_bufnr)
          --     vim.schedule(function()
          --       create_picker()
          --     end)
          --   end)
          --
          --   map("n", "<C-a>", function()
          --     show_autosaves = not show_autosaves
          --     actions.close(prompt_bufnr)
          --     vim.schedule(function()
          --       create_picker()
          --     end)
          --   end)
          --
          --   return true
        end,
      })
      :find()
  end

  create_picker()
end

-- function M.select()
--   local items = {}
--   for _, session in ipairs(M.list()) do
--     if uv.fs_stat(session) then
--       local file = session:sub(#Config.options.dir + 1, -5)
--
--       -- project_part tries to extract special encoded project names
--       local project_part = file:match("^(.-)%.%d%d%d%d%-%d%d%-%d%d_%d%d%-%d%d%-%d%d$")
--       if not project_part then
--         project_part = file
--       end
--
--       local dir
--       if project_part:find("%%") then
--         dir = project_part:gsub("%%", "/")
--       end
--
--       items[#items + 1] = { session = session, dir = dir }
--     end
--   end
--
--   vim.ui.select(items, {
--     prompt = "Select a session: ",
--     format_item = function(item)
--       local session_name = vim.fn.fnamemodify(item.session, ":t")
--       local is_autosave = item.session:find("/autosave/") ~= nil
--
--       local icon = is_autosave and "🚀" or "📝"
--
--       if item.dir then
--         return string.format("%s %s", icon, vim.fn.fnamemodify(item.dir, ":p:~"))
--       else
--         return string.format("%s %s", icon, session_name)
--       end
--     end,
--
--     -- format_item = function(item)
--     --   local session_name = vim.fn.fnamemodify(item.session, ":t")
--     --   return item.dir and (vim.fn.fnamemodify(item.dir, ":p:~")) or session_name
--     -- end,
--   }, function(item)
--     if item then
--       -- Only chdir if dir exists
--       if item.dir and vim.fn.isdirectory(item.dir) == 1 then
--         vim.fn.chdir(item.dir)
--         print("📂 Changed directory to: " .. item.dir)
--       end
--       -- Now load session
--       M.load(item.session)
--     end
--   end)
-- end

-- function M.select()
--   local items = {}
--   for _, session in ipairs(M.list()) do
--     if uv.fs_stat(session) then
--       local file = session:sub(#Config.options.dir + 1, -5)
--       local project_part = file:match("^(.-)%.%d%d%d%d%-%d%d%-%d%d_%d%d%-%d%d%-%d%d$")
--       if not project_part then
--         project_part = file
--       end
--       local dir, branch = unpack(vim.split(project_part, "%%", { plain = true }))
--       dir = dir:gsub("%%", "/")
--       if jit.os:find("Windows") then
--         dir = dir:gsub("^(%w)/", "%1:/")
--       end
--       items[#items + 1] = { session = session, dir = dir, branch = branch }
--     end
--   end
--   vim.ui.select(items, {
--     prompt = "Select a session: ",
--     format_item = function(item)
--       -- show project dir + extracted timestamp
--       local session_name = vim.fn.fnamemodify(item.session, ":t")
--       local timestamp = session_name:match("%.([%d_%-]+)%.vim$") or "no-timestamp"
--       return string.format("%s  🕒 %s", vim.fn.fnamemodify(item.dir, ":p:~"), timestamp)
--     end,
--
--     -- format_item = function(item)
--     --   return vim.fn.fnamemodify(item.dir, ":p:~")
--     -- end,
--   }, function(item)
--     if item then
--       vim.fn.chdir(item.dir)
--       -- M.load()
--       M.load(item.session)
--     end
--   end)
-- end

--- get current branch name
---@return string?
function M.branch()
  if uv.fs_stat(".git") then
    local ret = vim.fn.systemlist("git branch --show-current")[1]
    return vim.v.shell_error == 0 and ret or nil
  end
end

-- local function has_unsaved_changes()
--   for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
--     if vim.api.nvim_buf_get_option(bufnr, "modified") then
--       return true
--     end
--   end
--   return false
-- end
local function has_unsaved_changes()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
      local buftype = vim.api.nvim_buf_get_option(bufnr, "buftype")
      if buftype == "" then
        local name = vim.api.nvim_buf_get_name(bufnr)
        local modified = vim.api.nvim_buf_get_option(bufnr, "modified")
        if (name ~= "" or modified) and modified then
          return true
        end
      end
    end
  end
  return false
end

function M.quit_with_session_prompt(quit_command, unsaved_changes_ok)
  local unsaved = has_unsaved_changes()

  if unsaved and not unsaved_changes_ok then
    vim.notify("❗ You have unsaved changes.\nPlease review and try again!", vim.log.levels.WARN)
    return
  end

  vim.ui.select({ "💾 Save Session", "🚪 Just Quit", "❌ Cancel" }, {
    prompt = "Save session before quitting?",
  }, function(choice)
    if choice == "💾 Save Session" then
      require("persistence").save_session_with_picker()
      -- vim.cmd(quit_command) -- this is done inside s
    elseif choice == "🚪 Just Quit" then
      require("persistence").autosave()
      vim.cmd(quit_command)
    elseif choice == "❌ Cancel" or choice == nil then
      print("❌ Cancelled quit — staying inside Neovim")
    else
      print("❌ Cancelled — unknown case")
    end
  end)
end

-- function M.setup_quit_prompts()
--   -- Main wrapper: show session prompt, then execute real command
--   vim.api.nvim_create_user_command("QuitSessionPromptUnsavedChangesOk", function(opts)
--     local command = opts.fargs[1]
--     -- local unsaved = has_unsaved_changes()
--
--     -- if unsaved then
--     --   vim.notify("❗ You have unsaved changes.\nPlease review and try again!", vim.log.levels.WARN)
--     --   -- ❌ Stay inside Neovim
--     --   return
--     -- end
--
--     vim.ui.select({ "💾 Save Session", "🚪 Just Quit", "❌ Cancel" }, {
--       prompt = "Save session before quitting?",
--     }, function(choice)
--       if choice == "💾 Save Session" then
--         require("persistence").save_session_with_picker()
--       elseif choice == "🚪 Just Quit" then
--         require("persistence").autosave()
--         vim.cmd(command)
--       elseif choice == "❌ Cancel" or choice == nil then
--         print("❌ Cancelled quit — staying inside Neovim")
--       else
--         print("❌ Cancelled — unknown case")
--       end
--     end)
--   end, { nargs = 1 })
--
--   vim.api.nvim_create_user_command("QuitSessionPromptUnsavedChangesNotOk", function(opts)
--     local command = opts.fargs[1]
--     local unsaved = has_unsaved_changes()
--
--     if unsaved then
--       vim.notify("❗ You have unsaved changes.\nPlease review and try again!", vim.log.levels.WARN)
--       -- ❌ Stay inside Neovim
--       return
--     end
--
--     vim.ui.select({ "💾 Save Session", "🚪 Just Quit", "❌ Cancel" }, {
--       prompt = "Save session before quitting?",
--     }, function(choice)
--       if choice == "💾 Save Session" then
--         require("persistence").save_session_with_picker()
--       elseif choice == "🚪 Just Quit" then
--         require("persistence").autosave()
--         vim.cmd(command)
--       elseif choice == "❌ Cancel" or choice == nil then
--         print("❌ Cancelled quit — staying inside Neovim")
--       else
--         print("❌ Cancelled — unknown case")
--       end
--     end)
--   end, { nargs = 1 })
-- end

-- function M.setup_quit_nosave_abbreviations()
--   -- Map all quitting commands to our wrapper
--   local quit_commands = {
--     "q",
--     "q!",
--     "qa",
--     "qa!",
--     -- "wq",
--     -- "wq!",
--     -- "wqa",
--     -- "wqa!",
--   }
--
--   for _, cmd in ipairs(quit_commands) do
--     vim.cmd("cabbrev " .. cmd .. " QuitWithSessionPrompt " .. cmd)
--   end
-- end

-- function M.setup_quit_save_abbreviations()
--   -- Map all quitting commands to our wrapper
--   local quit_commands = {
--     "wq",
--     "wq!",
--     "wqa",
--     "wqa!",
--   }
--
--   for _, cmd in ipairs(quit_commands) do
--     vim.cmd("cabbrev " .. cmd .. " QuitWithSessionPrompt " .. cmd)
--   end
-- end

function M.setup_quit_save_abbreviations()
  -- vim.api.nvim_create_user_command("QuitSessionPromptQ", function()
  --   require("persistence").quit_with_session_prompt("q", false)
  -- end, { nargs = 0 })
  --
  -- vim.api.nvim_create_user_command("QuitSessionPromptQBang", function()
  --   require("persistence").quit_with_session_prompt("q!", true)
  -- end, { nargs = 0 })
  -- vim.api.nvim_create_user_command("QuitSessionPromptQ", function(opts)
  --   require("persistence").quit_with_session_prompt("q" .. (opts.bang and "!" or ""), opts.bang)
  -- end, { nargs = 0, bang = true })
  vim.api.nvim_create_user_command("QuitSessionPromptQ", function(opts)
    require("persistence").quit_behavior(opts)
  end, { nargs = 0, bang = true })

  -- vim.api.nvim_create_user_command("QuitSessionPromptQA", function()
  --   require("persistence").quit_with_session_prompt("qa", false)
  -- end, { nargs = 0 })
  --
  -- vim.api.nvim_create_user_command("QuitSessionPromptQABang", function()
  --   require("persistence").quit_with_session_prompt("qa!", true)
  -- end, { nargs = 0 })
  vim.api.nvim_create_user_command("QuitSessionPromptQA", function(opts)
    require("persistence").quit_with_session_prompt("qa" .. (opts.bang and "!" or ""), opts.bang)
  end, { nargs = 0, bang = true })

  -- vim.api.nvim_create_user_command("QuitSessionPromptWQ", function()
  --   vim.cmd("wall")
  --   require("persistence").quit_with_session_prompt("q", false)
  -- end, { nargs = 0 })
  --
  -- vim.api.nvim_create_user_command("QuitSessionPromptWQBang", function()
  --   vim.cmd("wall")
  --   require("persistence").quit_with_session_prompt("q!", false)
  -- end, { nargs = 0 })
  vim.api.nvim_create_user_command("QuitSessionPromptWQ", function(opts)
    vim.cmd("wall")
    require("persistence").quit_with_session_prompt("q" .. (opts.bang and "!" or ""), opts.bang)
  end, { nargs = 0, bang = true })

  -- vim.api.nvim_create_user_command("QuitSessionPromptWQA", function()
  --   vim.cmd("wall")
  --   require("persistence").quit_with_session_prompt("qa", false)
  -- end, { nargs = 0 })
  --
  -- vim.api.nvim_create_user_command("QuitSessionPromptWQABang", function()
  --   vim.cmd("wall")
  --   require("persistence").quit_with_session_prompt("qa!", false)
  -- end, { nargs = 0 })
  vim.api.nvim_create_user_command("QuitSessionPromptWQA", function(opts)
    vim.cmd("wall")
    require("persistence").quit_with_session_prompt("qa" .. (opts.bang and "!" or ""), opts.bang)
  end, { nargs = 0, bang = true })

  -- Command-line abbreviations
  vim.cmd("cabbrev q QuitSessionPromptQ")
  vim.cmd("cabbrev q! QuitSessionPromptQ")
  vim.cmd("cabbrev qa QuitSessionPromptQA")
  vim.cmd("cabbrev qa! QuitSessionPromptQA")
  vim.cmd("cabbrev wq QuitSessionPromptWQ")
  vim.cmd("cabbrev wq! QuitSessionPromptWQ")
  vim.cmd("cabbrev wqa QuitSessionPromptWQA")
  vim.cmd("cabbrev wqa! QuitSessionPromptWQA")
  -- vim.cmd("cabbrev q QuitSessionPromptQ")
  -- vim.cmd("cabbrev q! QuitSessionPromptQBang")
  -- vim.cmd("cabbrev qa QuitSessionPromptQA")
  -- vim.cmd("cabbrev qa! QuitSessionPromptQABang")
  -- vim.cmd("cabbrev wq QuitSessionPromptWQ")
  -- vim.cmd("cabbrev wq! QuitSessionPromptWQBang")
  -- vim.cmd("cabbrev wqa QuitSessionPromptWQA")
  -- vim.cmd("cabbrev wqa! QuitSessionPromptWQABang")
end

local function is_real_window(win)
  local buf = vim.api.nvim_win_get_buf(win)

  if not vim.api.nvim_buf_is_loaded(buf) then
    return false
  end

  if vim.api.nvim_buf_get_option(buf, "buftype") ~= "" then
    return false
  end

  local config = vim.api.nvim_win_get_config(win)
  if config.relative and config.relative ~= "" then
    return false
  end

  -- Optional: if the buffer is unnamed ("") but modified, still count it
  local name = vim.api.nvim_buf_get_name(buf)
  if name == "" and not vim.api.nvim_buf_get_option(buf, "modified") then
    return false
  end

  return true
end

local function has_real_unsaved_changes()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
      local buftype = vim.api.nvim_buf_get_option(bufnr, "buftype")
      if buftype == "" then
        local name = vim.api.nvim_buf_get_name(bufnr)
        local modified = vim.api.nvim_buf_get_option(bufnr, "modified")
        -- Important:
        -- Only warn if the buffer is NAMED and MODIFIED
        -- OR if it's unnamed ("") but modified
        if (name ~= "" or modified) and modified then
          return true
        end
      end
    end
  end
  return false
end

function M.quit_behavior(opts)
  -- if has_real_unsaved_changes() then
  --   vim.ui.select({ "💾 Save All", "❌ Cancel" }, {
  --     prompt = "You have unsaved changes. What do you want to do?",
  --   }, function(choice)
  --     if choice == "💾 Save All" then
  --       vim.cmd("wall")
  --       require("persistence").quit_behavior(opts)
  --     else
  --       print("❌ Quit canceled.")
  --     end
  --   end)
  --   return
  -- end
  --
  --

  local current_win = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_win_get_buf(current_win)
  local buftype = vim.api.nvim_buf_get_option(buf, "buftype")

  if buftype ~= "" then
    print("🌀 In a special window (buftype = " .. buftype .. "), just closing")
    vim.cmd(opts.bang and "close!" or "close")
    return
  end

  local file_wins = 0
  local total_wins = 0
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    total_wins = total_wins + 1
    if is_real_window(win) then
      file_wins = file_wins + 1
    end
  end

  local tabpages = vim.api.nvim_list_tabpages()

  print("🌟 quit_behavior called:")
  print("   file_wins = " .. file_wins)
  print("   total_wins = " .. total_wins)
  print("   tabpages = " .. #tabpages)

  -- if total_wins > 1 then
  --   vim.cmd(opts.bang and "close!" or "close")
  -- elseif #tabpages > 1 then
  --   vim.cmd(opts.bang and "tabclose!" or "tabclose")
  -- else
  --   require("persistence").quit_with_session_prompt("qa" .. (opts.bang and "!" or ""), opts.bang)
  -- end
  -- if file_wins > 1 then
  --   vim.cmd(opts.bang and "close!" or "close")
  -- elseif #tabpages > 1 then
  --   vim.cmd(opts.bang and "tabclose!" or "tabclose")
  -- elseif file_wins == 1 then
  --   vim.cmd(opts.bang and "close!" or "close")
  -- elseif file_wins == 0 and total_wins > 0 then
  --   vim.cmd(opts.bang and "close!" or "close")
  -- else
  --   require("persistence").quit_with_session_prompt("qa" .. (opts.bang and "!" or ""), opts.bang)
  -- end
  -- if file_wins > 1 then
  --   print("🌀 Case: more than 1 file window → close window")
  --   vim.cmd(opts.bang and "close!" or "close")
  -- elseif #tabpages > 1 then
  --   print("🌀 Case: more than 1 tab → close tab")
  --   vim.cmd(opts.bang and "tabclose!" or "tabclose")
  -- elseif file_wins == 1 and total_wins > 0 then
  --   print("🌀 Case: 1 real window but multiple total wins → close window")
  --   for _, win in ipairs(vim.api.nvim_list_wins()) do
  --     local buf = vim.api.nvim_win_get_buf(win)
  --     local buftype = vim.api.nvim_buf_get_option(buf, "buftype")
  --     local filetype = vim.api.nvim_buf_get_option(buf, "filetype")
  --     local name = vim.api.nvim_buf_get_name(buf)
  --     local config = vim.api.nvim_win_get_config(win)
  --
  --     print(
  --       string.format(
  --         "Window %d: buftype='%s', filetype='%s', name='%s', relative='%s'",
  --         win,
  --         buftype,
  --         filetype,
  --         name,
  --         config.relative
  --       )
  --     )
  --   end
  --
  --   -- 1 real window + quickfix or others: close normally
  --   vim.cmd(opts.bang and "close!" or "close")
  -- else
  --   print("🌀 Case: last real window → trigger save session prompt")
  --   -- Last real window: trigger save session before quitting
  --   require("persistence").quit_with_session_prompt("qa" .. (opts.bang and "!" or ""), opts.bang)
  -- end

  if file_wins > 1 then
    print("🌀 Case: more than 1 file window → close window")
    vim.cmd(opts.bang and "close!" or "close")
  elseif #tabpages > 1 then
    print("🌀 Case: more than 1 tab → close tab")
    vim.cmd(opts.bang and "tabclose!" or "tabclose")
  elseif file_wins == 1 and total_wins > 1 then
    if #tabpages == 1 then
      print("🌀 Case: 1 real window, multiple splits/floats, 1 tab → SAVE SESSION")
      require("persistence").quit_with_session_prompt("qa" .. (opts.bang and "!" or ""), opts.bang)
    else
      print("🌀 Case: 1 real window, multiple splits/floats, multiple tabs → close tab")
      vim.cmd(opts.bang and "tabclose!" or "tabclose")
    end
  else
    print("🌀 Case: last real window → SAVE SESSION")
    require("persistence").quit_with_session_prompt("qa" .. (opts.bang and "!" or ""), opts.bang)
  end
end

-- function M.quit_behavior(opts)
--   local wins = vim.api.nvim_list_wins()
--   local normal_wins = 0
--   for _, win in ipairs(wins) do
--     local config = vim.api.nvim_win_get_config(win)
--     if not config.relative or config.relative == "" then
--       normal_wins = normal_wins + 1
--     end
--   end
--
--   local tabpages = vim.api.nvim_list_tabpages()
--
--   if normal_wins > 1 then
--     -- 🌀 More than one window: just close the window
--     vim.cmd(opts.bang and "close!" or "close")
--   elseif #tabpages > 1 then
--     -- 🌀 Only one window, but multiple tabs: close the tab
--     vim.cmd(opts.bang and "tabclose!" or "tabclose")
--   else
--     -- 🌀 Only one tab, one window: exit Neovim
--     require("persistence").quit_with_session_prompt("qa" .. (opts.bang and "!" or ""), opts.bang)
--   end
-- end
--
-- function M.setup_quit_save_abbreviations()
--   vim.api.nvim_create_user_command("q", function()
--     vim.cmd("QuitWithSessionPrompt") -- unsaved changes are not ok
--     vim.cmd("q")
--   end, { nargs = 0 })
--
--   vim.api.nvim_create_user_command("q!", function()
--     vim.cmd("QuitWithSessionPrompt") -- here unsaved changes are ok
--     vim.cmd("q!")
--   end, { nargs = 0 })
--
--   vim.api.nvim_create_user_command("qa", function()
--     vim.cmd("QuitWithSessionPrompt") -- here unsaved changes are not ok
--     vim.cmd("qa")
--   end, { nargs = 0 })
--
--   vim.api.nvim_create_user_command("qa!", function()
--     vim.cmd("QuitWithSessionPrompt") -- here unsaved changes are ok
--     vim.cmd("qa!")
--   end, { nargs = 0 })
--
--   -- in all of these we save either way
--   vim.api.nvim_create_user_command("wq", function()
--     vim.cmd("w")
--     vim.cmd("QuitWithSessionPrompt")
--     vim.cmd("q")
--   end, { nargs = 0 })
--
--   vim.api.nvim_create_user_command("wq!", function()
--     vim.cmd("w")
--     vim.cmd("QuitWithSessionPrompt")
--     vim.cmd("q!")
--   end, { nargs = 0 })
--
--   vim.api.nvim_create_user_command("wqa", function()
--     vim.cmd("wall")
--     vim.cmd("QuitWithSessionPrompt")
--     vim.cmd("qall")
--   end, { nargs = 0 })
--
--   vim.api.nvim_create_user_command("wqa!", function()
--     vim.cmd("wall")
--     vim.cmd("QuitWithSessionPrompt")
--     vim.cmd("qall!")
--   end, { nargs = 0 })
-- end

-- function M.setup_quit_commands()
--   vim.api.nvim_create_user_command("Q", function()
--     local curr_tabpage = vim.api.nvim_get_current_tabpage()
--     local wins = vim.api.nvim_tabpage_list_wins(curr_tabpage)
--
--     -- Count *normal* windows (no floating, no special)
--     local normal_wins = 0
--     for _, win in ipairs(wins) do
--       local config = vim.api.nvim_win_get_config(win)
--       if not config.relative or config.relative == "" then
--         normal_wins = normal_wins + 1
--       end
--     end
--
--     local tabpages = vim.api.nvim_list_tabpages()
--
--     if normal_wins > 1 then
--       -- 🌀 More than one window: close window (split)
--       vim.cmd("close")
--     elseif #tabpages > 1 then
--       -- 🌀 More than one tabpage: close tab
--       vim.cmd("tabclose")
--     else
--       -- 🌀 Only one tabpage, one window: trigger save/quit prompt
--       vim.ui.select({ "💾 Save Session and Quit", "🚪 Just Quit", "❌ Cancel" }, {
--         prompt = "Save session before quitting?",
--       }, function(choice)
--         if choice == "💾 Save Session and Quit" then
--           M.save_session_with_picker()
--         elseif choice == "🚪 Just Quit" then
--           M.autosave()
--           vim.cmd("qa!")
--         elseif choice == "❌ Cancel" or choice == nil then
--           print("❌ Cancelled quit — staying inside Neovim")
--         else
--           print("❌ Escape — staying inside Neovim")
--         end
--       end)
--     end
--   end, {})
--
--   -- Fix lowercase mappings
--   vim.cmd("cabbrev q Q")
--   vim.cmd("cabbrev qa Q")
--   vim.cmd("cabbrev wq Q")
--   vim.cmd("cabbrev q! Q")
--   vim.cmd("cabbrev qa! Q")
--   vim.cmd("cabbrev wq! Q")
--   vim.cmd("cabbrev wqa! Q")
-- end

-- function M.setup_quit_commands()
--   vim.api.nvim_create_user_command("Qsmart", function(opts)
--     local tabpages = vim.api.nvim_list_tabpages()
--     local current_tab = vim.api.nvim_get_current_tabpage()
--     local wins = vim.api.nvim_tabpage_list_wins(current_tab)
--
--     local normal_wins = 0
--     for _, win in ipairs(wins) do
--       local config = vim.api.nvim_win_get_config(win)
--       if not config.relative or config.relative == "" then
--         normal_wins = normal_wins + 1
--       end
--     end
--
--     -- 🌟 Detect if user typed qa, wqa, etc
--     local is_quit_all = vim.fn.expand("<abuf>") == "" -- (meaning no specific buffer targeted)
--
--     -- 🌟 Always save buffers
--     vim.cmd(opts.bang and "wall!" or "wall")
--
--     if is_quit_all or (#tabpages == 1 and normal_wins == 1) then
--       -- 🌀 Exiting NVIM (only 1 window/tab)
--       vim.ui.select({ "💾 Save Session and Quit", "🚪 Just Quit", "❌ Cancel" }, {
--         prompt = "Save session before quitting?",
--       }, function(choice)
--         if choice == "💾 Save Session and Quit" then
--           require("persistence").save_session_with_picker()
--         elseif choice == "🚪 Just Quit" then
--           require("persistence").autosave()
--           vim.cmd("qa" .. (opts.bang and "!" or ""))
--         elseif choice == "❌ Cancel" or choice == nil then
--           print("❌ Cancelled quit — staying inside Neovim")
--         else
--           print("❌ Escape — staying inside Neovim")
--         end
--       end)
--     elseif #tabpages > 1 then
--       vim.cmd("tabclose")
--     else
--       vim.cmd("close")
--     end
--   end, { bang = true })
--
--   -- Map everything to Qsmart
--   vim.cmd("cabbrev q Qsmart")
--   vim.cmd("cabbrev wq Qsmart")
--   vim.cmd("cabbrev q! Qsmart")
--   vim.cmd("cabbrev wq! Qsmart")
--   vim.cmd("cabbrev qa Qsmart")
--   vim.cmd("cabbrev qa! Qsmart")
--   vim.cmd("cabbrev wqa Qsmart")
--   vim.cmd("cabbrev wqa! Qsmart")
-- end
--

-- function M.setup_quit_commands()
--   vim.api.nvim_create_user_command("Q", function()
--     local wins = vim.api.nvim_list_wins()
--     local normal_wins = 0
--     for _, win in ipairs(wins) do
--       local config = vim.api.nvim_win_get_config(win)
--       if not config.relative or config.relative == "" then
--         normal_wins = normal_wins + 1
--       end
--     end
--
--     if normal_wins <= 1 then
--       -- 🌀 Only one window left: treat like closing NVIM
--       vim.ui.select({ "💾 Save Session and Quit", "🚪 Just Quit", "❌ Cancel" }, {
--         prompt = "Save session before quitting?",
--       }, function(choice)
--         if choice == "💾 Save Session and Quit" then
--           M.save_session_with_picker()
--         elseif choice == "🚪 Just Quit" then
--           M.autosave()
--           vim.cmd("qa!")
--         elseif choice == "❌ Cancel" or choice == nil then
--           print("❌ Cancelled quit — staying inside Neovim")
--         else
--           print("❌ Escape — staying inside Neovim")
--         end
--       end)
--     else
--       -- 🌀 More than one window: just close the window
--       vim.cmd("close")
--     end
--   end, {})
--
--   -- Fix lowercase mappings
--   vim.cmd("cabbrev q Q")
--   vim.cmd("cabbrev qa Q")
--   vim.cmd("cabbrev wq Q")
--   vim.cmd("cabbrev q! Q")
--   vim.cmd("cabbrev qa! Q")
--   vim.cmd("cabbrev wq! Q")
--   vim.cmd("cabbrev wqa! Q")
-- end

-- function M.setup_quit_commands()
--   vim.api.nvim_create_user_command("Q", function()
--     local wins = vim.api.nvim_list_wins()
--     local normal_wins = 0
--     for _, win in ipairs(wins) do
--       local config = vim.api.nvim_win_get_config(win)
--       if not config.relative or config.relative == "" then
--         normal_wins = normal_wins + 1
--       end
--     end
--
--     if normal_wins <= 1 then
--       -- 🌀 Only one window left: treat like closing NVIM
--       vim.ui.select({ "💾 Save Session and Quit", "🚪 Just Quit", "❌ Cancel" }, {
--         prompt = "Save session before quitting?",
--       }, function(choice)
--         if choice == "💾 Save Session and Quit" then
--           M.save_session_with_picker()
--         elseif choice == "🚪 Just Quit" then
--           M.autosave()
--           vim.cmd("qa!")
--         elseif choice == "❌ Cancel" or choice == nil then
--           print("❌ Cancelled quit — staying inside Neovim")
--         else
--           print("❌ Escape — staying inside Neovim")
--         end
--       end)
--     else
--       -- 🌀 More than one window: just close the window
--       vim.cmd("close")
--     end
--   end, {})
--
--   -- Fix lowercase mappings
--   -- vim.cmd("cabbrev q Q")
--   vim.cmd("cabbrev qa Q")
--   vim.cmd("cabbrev wq Q")
--   vim.cmd("cabbrev wqa Q")
--   vim.cmd("cabbrev q! Q")
--   vim.cmd("cabbrev qa! Q")
--   vim.cmd("cabbrev wq! Q")
--   vim.cmd("cabbrev wqa! Q")
-- end

function M.list_projects()
  local sessions = M.list()
  local projects = {}

  for _, session in ipairs(sessions) do
    local filename = vim.fn.fnamemodify(session, ":t:r")

    local is_autosave = filename:sub(1, 1) == "%"
    local project

    if is_autosave then
      project = filename -- Keep %home%anna%30_notes
    else
      project = filename -- No % decoding needed here
    end

    projects[#projects + 1] = {
      project = project,
      path = session,
      is_autosave = is_autosave,
    }
  end

  return projects
end

-- function M.list_projects()
--   local sessions = M.list()
--   local projects = {}
--
--   for _, session in ipairs(sessions) do
--     local file = vim.fn.fnamemodify(session, ":t:r")
--     local dir = file:gsub("%%", "/")
--     projects[#projects + 1] = { project = dir, path = session }
--   end
--
--   return projects
-- end

function M.save_session_with_picker()
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  local sessions = M.list_projects()
  local session_names = {}

  local default_text = (M._last_session_loaded and not M._last_session_loaded:find("^%%")) and M._last_session_loaded
    or ""

  -- 🧹 Filter sessions: only those that do NOT start with %
  for _, item in ipairs(sessions) do
    if not item.is_autosave then
      table.insert(session_names, item.project)
    end
  end

  -- for _, item in ipairs(sessions) do
  --   if not item.project:find("^%%") then
  --     table.insert(session_names, item.project)
  --   end
  -- end

  pickers
    .new({}, {
      prompt_title = "Save Session As",
      finder = finders.new_table({
        results = session_names,
        entry_maker = function(entry)
          return {
            value = entry,
            display = "🚀 " .. entry,
            ordinal = entry,
          }
        end,
      }),
      sorter = conf.generic_sorter({}),
      -- default_text = (M._last_session_loaded and not M._last_session_loaded:find("^%%")) and M._last_session_loaded
      --   or "",
      default_text = default_text,
      attach_mappings = function(prompt_bufnr, map)
        local function save_session()
          local entry = action_state.get_selected_entry()
          local input = action_state.get_current_line()

          local name_to_use
          if entry and entry.value then
            name_to_use = entry.value
          elseif input and input ~= "" then
            name_to_use = input
          else
            print("❌ No project name entered, aborting save")
            actions.close(prompt_bufnr)
            return
          end

          local session_name = name_to_use:gsub("/", "%%") .. ".vim"
          local session_path = Config.options.dir .. session_name

          -- local default_text = (M._last_session_loaded and not M._last_session_loaded:find("^%%"))
          --     and M._last_session_loaded
          --   or ""

          if vim.fn.filereadable(session_path) == 1 then
            actions.close(prompt_bufnr) -- close before opening UI
            vim.defer_fn(function()
              local overwrite_prompt
              if name_to_use == default_text then
                overwrite_prompt = "Overwriting original session. Proceed?"
              else
                overwrite_prompt = "Session exists! [Orig: "
                  .. default_text
                  .. "] [Existing: "
                  .. name_to_use
                  .. "] Overwrite?"
                -- overwrite_prompt = "Session already exists.\nOriginal Session: "
                --   .. default_text
                --   .. "\nChosen Session: "
                --   .. name_to_use
                --   .. "\nOverwrite?"
              end

              vim.ui.select({ "✅ Overwrite", "❌ Cancel" }, {
                prompt = overwrite_prompt,
              }, function(choice)
                if choice == "✅ Overwrite" then
                  vim.cmd("mks! " .. vim.fn.fnameescape(session_path))
                  print("✅ Session overwritten: " .. name_to_use)
                  vim.cmd("qa!")
                else
                  print("❌ Aborted saving session")
                end
              end)
            end, 10)
          else
            vim.cmd("mks! " .. vim.fn.fnameescape(session_path))
            print("✅ New session saved: " .. name_to_use)
            actions.close(prompt_bufnr)
            vim.cmd("qa!")
          end
        end

        map("i", "<CR>", save_session)
        map("n", "<CR>", save_session)
        return true
      end,
    })
    :find()
end

-- function M.autosave()
--   local session_path = M.current()
--   if session_path then
--     vim.cmd("silent! mks! " .. vim.fn.fnameescape(session_path))
--     print("📦 Autosaved session to: " .. session_path)
--   end
-- end
-- function M.autosave()
--   local base_path = M.current()
--   if base_path then
--     local timestamp = os.date("%Y-%m-%d_%H-%M-%S")
--     local autosave_path = base_path:gsub("%.vim$", ".autosave." .. timestamp .. ".vim")
--
--     vim.cmd("silent! mks! " .. vim.fn.fnameescape(autosave_path))
--     print("📦 Autosaved session to: " .. autosave_path)
--   end
-- end
-- function M.autosave()
--   local base_path = M.current()
--   if base_path then
--     -- local timestamp = os.date("%Y-%m-%d_%H-%M-%S")
--
--     local autosave_dir = Config.options.dir .. "autosave/"
--     vim.fn.mkdir(autosave_dir, "p") -- ensure folder exists
--
--     local filename = vim.fn.fnamemodify(base_path, ":t:r") -- filename only, no extension
--     -- local autosave_path = autosave_dir .. filename .. ".autosave." .. timestamp .. ".vim"
--     local autosave_path = autosave_dir .. filename .. ".vim"
--
--     vim.cmd("silent! mks! " .. vim.fn.fnameescape(autosave_path))
--     print("📦 Autosaved session to: " .. autosave_path)
--   end
-- end
function M.autosave()
  vim.cmd("silent! mks! " .. vim.fn.fnameescape(M.current({ autosave = true })))
  print("📦 Autosaved session")
end

function M.setup_win_closed_detection()
  vim.api.nvim_create_autocmd("WinClosed", {
    callback = function()
      -- Check how many normal windows are left
      local wins = vim.api.nvim_list_wins()
      local normal_wins = 0
      for _, win in ipairs(wins) do
        local config = vim.api.nvim_win_get_config(win)
        if not config.relative or config.relative == "" then
          normal_wins = normal_wins + 1
        end
      end

      -- If no normal windows remain, show the save picker
      if normal_wins == 0 then
        vim.schedule(function()
          require("persistence").save_session_with_picker()
        end)
      end
    end,
  })
end

return M
