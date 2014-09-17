Workspace = require '../src/workspace'
{View} = require '../src/space-pen-extensions'

describe "Workspace", ->
  workspace = null

  beforeEach ->
    atom.project.setPath(atom.project.resolve('dir'))
    atom.workspace = workspace = new Workspace

  describe "::getView(object)", ->
    describe "when passed a DOM node", ->
      it "returns the given DOM node", ->
        node = document.createElement('div')
        expect(workspace.getView(node)).toBe node

    describe "when passed a SpacePen view", ->
      it "returns the root node of the view with a __spacePenView property pointing at the SpacePen view", ->
        class TestView extends View
          @content: -> @div "Hello"

        view = new TestView
        node = workspace.getView(view)
        expect(node.textContent).toBe "Hello"
        expect(node.__spacePenView).toBe view

    describe "when passed a model object", ->
      describe "when no view provider is registered for the object's constructor", ->
        describe "when the object has a .getViewClass() method", ->
          it "builds an instance of the view class with the model, then returns its root node with a __spacePenView property pointing at the view", ->
            class TestView extends View
              @content: (model) -> @div model.name
              initialize: (@model) ->

            class TestModel
              constructor: (@name) ->
              getViewClass: -> TestView

            model = new TestModel("hello")
            node = workspace.getView(model)

            expect(node.textContent).toBe "hello"
            view = node.__spacePenView
            expect(view instanceof TestView).toBe true
            expect(view.model).toBe model

            # returns the same DOM node for repeated calls
            expect(workspace.getView(model)).toBe node

        describe "when the object has no .getViewClass() method", ->
          it "throws an exception", ->
            expect(-> workspace.getView(new Object)).toThrow()

  describe "::open(uri, options)", ->
    openEvents = null

    beforeEach ->
      openEvents = []
      workspace.onDidOpen (event) -> openEvents.push(event)
      spyOn(workspace.getActivePane(), 'activate').andCallThrough()

    describe "when the 'searchAllPanes' option is false (default)", ->
      describe "when called without a uri", ->
        it "adds and activates an empty editor on the active pane", ->
          [editor1, editor2] = []

          waitsForPromise ->
            workspace.open().then (editor) -> editor1 = editor

          runs ->
            expect(editor1.getPath()).toBeUndefined()
            expect(workspace.getActivePane().items).toEqual [editor1]
            expect(workspace.getActivePaneItem()).toBe editor1
            expect(workspace.getActivePane().activate).toHaveBeenCalled()
            expect(openEvents).toEqual [{uri: undefined, pane: workspace.getActivePane(), item: editor1, index: 0}]
            openEvents = []

          waitsForPromise ->
            workspace.open().then (editor) -> editor2 = editor

          runs ->
            expect(editor2.getPath()).toBeUndefined()
            expect(workspace.getActivePane().items).toEqual [editor1, editor2]
            expect(workspace.getActivePaneItem()).toBe editor2
            expect(workspace.getActivePane().activate).toHaveBeenCalled()
            expect(openEvents).toEqual [{uri: undefined, pane: workspace.getActivePane(), item: editor2, index: 1}]

      describe "when called with a uri", ->
        describe "when the active pane already has an editor for the given uri", ->
          it "activates the existing editor on the active pane", ->
            editor = null
            editor1 = null
            editor2 = null

            waitsForPromise ->
              workspace.open('a').then (o) ->
                editor1 = o
                workspace.open('b').then (o) ->
                  editor2 = o
                  workspace.open('a').then (o) ->
                    editor = o

            runs ->
              expect(editor).toBe editor1
              expect(workspace.getActivePaneItem()).toBe editor
              expect(workspace.getActivePane().activate).toHaveBeenCalled()

              expect(openEvents).toEqual [
                {
                  uri: atom.project.resolve('a')
                  item: editor1
                  pane: atom.workspace.getActivePane()
                  index: 0
                }
                {
                  uri: atom.project.resolve('b')
                  item: editor2
                  pane: atom.workspace.getActivePane()
                  index: 1
                }
                {
                  uri: atom.project.resolve('a')
                  item: editor1
                  pane: atom.workspace.getActivePane()
                  index: 0
                }
              ]

        describe "when the active pane does not have an editor for the given uri", ->
          it "adds and activates a new editor for the given path on the active pane", ->
            editor = null
            waitsForPromise ->
              workspace.open('a').then (o) -> editor = o

            runs ->
              expect(editor.getUri()).toBe atom.project.resolve('a')
              expect(workspace.getActivePaneItem()).toBe editor
              expect(workspace.getActivePane().items).toEqual [editor]
              expect(workspace.getActivePane().activate).toHaveBeenCalled()

    describe "when the 'searchAllPanes' option is true", ->
      describe "when an editor for the given uri is already open on an inactive pane", ->
        it "activates the existing editor on the inactive pane, then activates that pane", ->
          editor1 = null
          editor2 = null
          pane1 = workspace.getActivePane()
          pane2 = workspace.getActivePane().splitRight()

          waitsForPromise ->
            pane1.activate()
            workspace.open('a').then (o) -> editor1 = o

          waitsForPromise ->
            pane2.activate()
            workspace.open('b').then (o) -> editor2 = o

          runs ->
            expect(workspace.getActivePaneItem()).toBe editor2

          waitsForPromise ->
            workspace.open('a', searchAllPanes: true)

          runs ->
            expect(workspace.getActivePane()).toBe pane1
            expect(workspace.getActivePaneItem()).toBe editor1

      describe "when no editor for the given uri is open in any pane", ->
        it "opens an editor for the given uri in the active pane", ->
          editor = null
          waitsForPromise ->
            workspace.open('a', searchAllPanes: true).then (o) -> editor = o

          runs ->
            expect(workspace.getActivePaneItem()).toBe editor

    describe "when the 'split' option is set", ->
      describe "when the 'split' option is 'left'", ->
        it "opens the editor in the leftmost pane of the current pane axis", ->
          pane1 = workspace.getActivePane()
          pane2 = pane1.splitRight()
          expect(workspace.getActivePane()).toBe pane2

          editor = null
          waitsForPromise ->
            workspace.open('a', split: 'left').then (o) -> editor = o

          runs ->
            expect(workspace.getActivePane()).toBe pane1
            expect(pane1.items).toEqual [editor]
            expect(pane2.items).toEqual []

          # Focus right pane and reopen the file on the left
          waitsForPromise ->
            pane2.focus()
            workspace.open('a', split: 'left').then (o) -> editor = o

          runs ->
            expect(workspace.getActivePane()).toBe pane1
            expect(pane1.items).toEqual [editor]
            expect(pane2.items).toEqual []

      describe "when a pane axis is the leftmost sibling of the current pane", ->
        it "opens the new item in the current pane", ->
          editor = null
          pane1 = workspace.getActivePane()
          pane2 = pane1.splitLeft()
          pane3 = pane2.splitDown()
          pane1.activate()
          expect(workspace.getActivePane()).toBe pane1

          waitsForPromise ->
            workspace.open('a', split: 'left').then (o) -> editor = o

          runs ->
            expect(workspace.getActivePane()).toBe pane1
            expect(pane1.items).toEqual [editor]

      describe "when the 'split' option is 'right'", ->
        it "opens the editor in the rightmost pane of the current pane axis", ->
          editor = null
          pane1 = workspace.getActivePane()
          pane2 = null
          waitsForPromise ->
            workspace.open('a', split: 'right').then (o) -> editor = o

          runs ->
            pane2 = workspace.getPanes().filter((p) -> p != pane1)[0]
            expect(workspace.getActivePane()).toBe pane2
            expect(pane1.items).toEqual []
            expect(pane2.items).toEqual [editor]

          # Focus right pane and reopen the file on the right
          waitsForPromise ->
            pane1.focus()
            workspace.open('a', split: 'right').then (o) -> editor = o

          runs ->
            expect(workspace.getActivePane()).toBe pane2
            expect(pane1.items).toEqual []
            expect(pane2.items).toEqual [editor]

        describe "when a pane axis is the rightmost sibling of the current pane", ->
          it "opens the new item in a new pane split to the right of the current pane", ->
            editor = null
            pane1 = workspace.getActivePane()
            pane2 = pane1.splitRight()
            pane3 = pane2.splitDown()
            pane1.activate()
            expect(workspace.getActivePane()).toBe pane1
            pane4 = null

            waitsForPromise ->
              workspace.open('a', split: 'right').then (o) -> editor = o

            runs ->
              pane4 = workspace.getPanes().filter((p) -> p != pane1)[0]
              expect(workspace.getActivePane()).toBe pane4
              expect(pane4.items).toEqual [editor]
              expect(workspace.paneContainer.root.children[0]).toBe pane1
              expect(workspace.paneContainer.root.children[1]).toBe pane4

    describe "when passed a path that matches a custom opener", ->
      it "returns the resource returned by the custom opener", ->
        fooOpener = (pathToOpen, options) -> { foo: pathToOpen, options } if pathToOpen?.match(/\.foo/)
        barOpener = (pathToOpen) -> { bar: pathToOpen } if pathToOpen?.match(/^bar:\/\//)
        workspace.registerOpener(fooOpener)
        workspace.registerOpener(barOpener)

        waitsForPromise ->
          pathToOpen = atom.project.resolve('a.foo')
          workspace.open(pathToOpen, hey: "there").then (item) ->
            expect(item).toEqual { foo: pathToOpen, options: {hey: "there"} }

        waitsForPromise ->
          workspace.open("bar://baz").then (item) ->
            expect(item).toEqual { bar: "bar://baz" }

    it "notifies ::onDidAddTextEditor observers", ->
      absolutePath = require.resolve('./fixtures/dir/a')
      newEditorHandler = jasmine.createSpy('newEditorHandler')
      workspace.onDidAddTextEditor newEditorHandler

      editor = null
      waitsForPromise ->
        workspace.open(absolutePath).then (e) -> editor = e

      runs ->
        expect(newEditorHandler.argsForCall[0][0].textEditor).toBe editor

  describe "::reopenItem()", ->
    it "opens the uri associated with the last closed pane that isn't currently open", ->
      pane = workspace.getActivePane()
      waitsForPromise ->
        workspace.open('a').then ->
          workspace.open('b').then ->
            workspace.open('file1').then ->
              workspace.open()

      runs ->
        # does not reopen items with no uri
        expect(workspace.getActivePaneItem().getUri()).toBeUndefined()
        pane.destroyActiveItem()

      waitsForPromise ->
        workspace.reopenItem()

      runs ->
        expect(workspace.getActivePaneItem().getUri()).not.toBeUndefined()

        # destroy all items
        expect(workspace.getActivePaneItem().getUri()).toBe atom.project.resolve('file1')
        pane.destroyActiveItem()
        expect(workspace.getActivePaneItem().getUri()).toBe atom.project.resolve('b')
        pane.destroyActiveItem()
        expect(workspace.getActivePaneItem().getUri()).toBe atom.project.resolve('a')
        pane.destroyActiveItem()

        # reopens items with uris
        expect(workspace.getActivePaneItem()).toBeUndefined()

      waitsForPromise ->
        workspace.reopenItem()

      runs ->
        expect(workspace.getActivePaneItem().getUri()).toBe atom.project.resolve('a')

      # does not reopen items that are already open
      waitsForPromise ->
        workspace.open('b')

      runs ->
        expect(workspace.getActivePaneItem().getUri()).toBe atom.project.resolve('b')

      waitsForPromise ->
        workspace.reopenItem()

      runs ->
        expect(workspace.getActivePaneItem().getUri()).toBe atom.project.resolve('file1')

  describe "::increase/decreaseFontSize()", ->
    it "increases/decreases the font size without going below 1", ->
      atom.config.set('editor.fontSize', 1)
      workspace.increaseFontSize()
      expect(atom.config.get('editor.fontSize')).toBe 2
      workspace.increaseFontSize()
      expect(atom.config.get('editor.fontSize')).toBe 3
      workspace.decreaseFontSize()
      expect(atom.config.get('editor.fontSize')).toBe 2
      workspace.decreaseFontSize()
      expect(atom.config.get('editor.fontSize')).toBe 1
      workspace.decreaseFontSize()
      expect(atom.config.get('editor.fontSize')).toBe 1

  describe "::openLicense()", ->
    it "opens the license as plain-text in a buffer", ->
      waitsForPromise -> workspace.openLicense()
      runs -> expect(workspace.getActivePaneItem().getText()).toMatch /Copyright/

  describe "::observeTextEditors()", ->
    it "invokes the observer with current and future text editors", ->
      observed = []

      waitsForPromise -> workspace.open()
      waitsForPromise -> workspace.open()
      waitsForPromise -> workspace.openLicense()

      runs ->
        workspace.observeTextEditors (editor) -> observed.push(editor)

      waitsForPromise -> workspace.open()

      expect(observed).toEqual workspace.getTextEditors()

  describe "when an editor is destroyed", ->
    it "removes the editor", ->
      editor = null

      waitsForPromise ->
        workspace.open("a").then (e) -> editor = e

      runs ->
        expect(workspace.getTextEditors()).toHaveLength 1
        editor.destroy()
        expect(workspace.getTextEditors()).toHaveLength 0

  it "stores the active grammars used by all the open editors", ->
    waitsForPromise ->
      atom.packages.activatePackage('language-javascript')

    waitsForPromise ->
      atom.packages.activatePackage('language-coffee-script')

    waitsForPromise ->
      atom.packages.activatePackage('language-todo')

    waitsForPromise ->
      atom.workspace.open('sample.coffee')

    runs ->
      atom.workspace.getActiveEditor().setText """
        i = /test/; #FIXME
      """

      state = atom.workspace.serialize()
      expect(state.packagesWithActiveGrammars).toEqual ['language-coffee-script', 'language-javascript', 'language-todo']

      jsPackage = atom.packages.getLoadedPackage('language-javascript')
      coffeePackage = atom.packages.getLoadedPackage('language-coffee-script')
      spyOn(jsPackage, 'loadGrammarsSync')
      spyOn(coffeePackage, 'loadGrammarsSync')

      workspace2 = Workspace.deserialize(state)
      expect(jsPackage.loadGrammarsSync.callCount).toBe 1
      expect(coffeePackage.loadGrammarsSync.callCount).toBe 1
