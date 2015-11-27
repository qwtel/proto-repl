{Task, Emitter} = require 'atom'
path = require 'path'
fs = require('fs')
ReplProcess = require.resolve './repl-process'

replHelpText = ";; This is a text editor and also a Clojure REPL.  It behaves
differently than a typical Clojure REPL. You can type anywhere and modify any of
the displayed text. Commands are not sent by typing in the REPL and pressing
enter. They are sent through keyboard shortcuts.\n
\n
;; REPL Execution Keybindings\n
;; Note: These keybindings can be executed from any file and the results will be
displayed in this REPL.\n
;; See the settings for more keybindings.\n
\n
;; cmd+alt+b - execute block. Finds the block of Clojure code your cursor is in
and executes that.\n
\n
;; Try it now. Put your cursor inside this block and press cmd+alt+b\n
(+ 2 3)\n
\n
;; cmd+alt+s - Executes the selection. Sends the selected text to the REPL.\n
\n
;; Try it now. Select these three lines and hit cmd + alt + s.\n
(println \"hello 1\")\n
(println \"hello 2\")\n
(println \"hello 3\")\n
\n
;; You can disable this help text in the settings.\n"

# The path to a default project to use if proto repl is started outside of a leiningen project
defaultProjectPath = "#{atom.packages.getPackageDirPaths()[0]}/proto-repl/proto-no-proj"

replClojureScript = "#{atom.packages.getPackageDirPaths()[0]}/proto-repl/lib/proto_repl.clj"

module.exports =
class ReplTextEditor
  # This is set to some string to strip out of the text displayed. It is used to remove code that
  # is sent to the repl because the repl will print the code that was sent to it.
  textToIgnore: null
  emitter: null

  constructor: ->
    @emitter = new Emitter
    projectPath = atom.project.getPaths()[0]

    # If we're not in a project or there isn't a leiningen project file use
    # the default project
    if !(projectPath?) || !fs.existsSync(projectPath + "/project.clj")
      projectPath = defaultProjectPath

    # Handles the text editor being closed.
    closingHandler =  =>
      try
        # I couldn't refer to exitRepl directly here. I'm not sure why.
        @process.send event: 'input', text: ":exit\n"
      catch error
        console.log("Warning error while closing: " + error)

    # Opens the text editor that will represent the REPL.
    atom.workspace.open("Clojure REPL", split:'right').done (textEditor) =>
      @textEditor = textEditor
      # Change the text editor so it will never require saving.
      @textEditor.isModified = -> false

      # Configure text editor for clojure syntax highlighting
      grammar = atom.grammars.grammarForScopeName('source.clojure')
      @textEditor.setGrammar(grammar)

      # Handle the text editor being closed
      @textEditor.onDidDestroy(closingHandler)

      # Set the text editor not to be wrapped.
      @textEditor.setSoftWrapped(true)

      # Display the help text when the repl opens.
      if atom.config.get("proto-repl.displayHelpText")
        @appendText(replHelpText)

      @appendText(";; Loading REPL...\n")

    # Start the repl process as a background task
    leinArgs = "trampoline run -m clojure.main #{replClojureScript}"
    @process = Task.once ReplProcess,
                         path.resolve(projectPath),
                         atom.config.get('proto-repl.leinPath').replace("/lein",""),
                         leinArgs.split(" ")
    @attachListeners()

  strToBytes: (s)->
    s.charCodeAt(n) for n in [0..s.length]

  autoscroll: ->
    if atom.config.get('proto-repl.autoScroll')
      @textEditor.scrollToBottom()

  appendText: (text)->
    @textEditor.getBuffer().append(text)
    @autoscroll()

  attachListeners: ->
    @process.on 'proto-repl-process:data', (data) =>
      @appendText(data)

    @process.on 'proto-repl-process:exit', ()=>
      @emitter.emit 'proto-repl-text-editor:exit'
      @appendText("\nREPL Closed\n")

  onDidExit: (callback)->
    @emitter.on 'proto-repl-text-editor:exit', callback

  executeCode: (ns, code)->
    escapedCode = code.replace(/\\/g,"\\\\").replace(/"/g, "\\\"")
    @process.send event: 'input', text: "{:ns-to-use #{ns} :code \"#{escapedCode}\"}\n"

  exitRepl: ()->
    @process.send event: 'input', text: ":exit\n"

  clear: ->
    @textEditor.setText("")
