{$, View} = require './space-pen-extensions'
Delegator = require 'delegato'
{deprecate} = require 'grim'
{CompositeDisposable} = require 'event-kit'
PropertyAccessors = require 'property-accessors'

Pane = require './pane'

# Extended: A container which can contains multiple items to be switched between.
#
# Items can be almost anything however most commonly they're {EditorView}s.
#
# Most packages won't need to use this class, unless you're interested in
# building a package that deals with switching between panes or items.
module.exports =
class PaneView extends View
  Delegator.includeInto(this)
  PropertyAccessors.includeInto(this)

  @version: 1

  @content: (wrappedView) ->
    @div class: 'pane', tabindex: -1, =>
      @div class: 'item-views', outlet: 'itemViews'

  @delegatesProperties 'items', 'activeItem', toProperty: 'model'
  @delegatesMethods 'getItems', 'activateNextItem', 'activatePreviousItem', 'getActiveItemIndex',
    'activateItemAtIndex', 'activateItem', 'addItem', 'itemAtIndex', 'moveItem', 'moveItemToPane',
    'destroyItem', 'destroyItems', 'destroyActiveItem', 'destroyInactiveItems',
    'saveActiveItem', 'saveActiveItemAs', 'saveItem', 'saveItemAs', 'saveItems',
    'itemForUri', 'activateItemForUri', 'promptToSaveItem', 'copyActiveItem', 'isActive',
    'activate', 'getActiveItem', toProperty: 'model'

  previousActiveItem: null

  initialize: (@model) ->
    @subscriptions = new CompositeDisposable
    @onItemAdded(item) for item in @items
    @handleEvents()

  handleEvents: ->
    @subscriptions.add @model.observeActiveItem(@onActiveItemChanged)
    @subscriptions.add @model.onDidAddItem(@onItemAdded)
    @subscriptions.add @model.onDidRemoveItem(@onItemRemoved)
    @subscriptions.add @model.onDidMoveItem(@onItemMoved)
    @subscriptions.add @model.onWillDestroyItem(@onBeforeItemDestroyed)
    @subscriptions.add @model.onDidActivate(@onActivated)
    @subscriptions.add @model.observeActive(@onActiveStatusChanged)

    @subscribe this, 'focusin', => @model.focus()
    @subscribe this, 'focusout', => @model.blur()
    @subscribe this, 'focus', =>
      @activeView?.focus()
      false

    @command 'pane:save-items', => @saveItems()
    @command 'pane:show-next-item', => @activateNextItem()
    @command 'pane:show-previous-item', => @activatePreviousItem()

    @command 'pane:show-item-1', => @activateItemAtIndex(0)
    @command 'pane:show-item-2', => @activateItemAtIndex(1)
    @command 'pane:show-item-3', => @activateItemAtIndex(2)
    @command 'pane:show-item-4', => @activateItemAtIndex(3)
    @command 'pane:show-item-5', => @activateItemAtIndex(4)
    @command 'pane:show-item-6', => @activateItemAtIndex(5)
    @command 'pane:show-item-7', => @activateItemAtIndex(6)
    @command 'pane:show-item-8', => @activateItemAtIndex(7)
    @command 'pane:show-item-9', => @activateItemAtIndex(8)

    @command 'pane:split-left', => @model.splitLeft(copyActiveItem: true)
    @command 'pane:split-right', => @model.splitRight(copyActiveItem: true)
    @command 'pane:split-up', => @model.splitUp(copyActiveItem: true)
    @command 'pane:split-down', => @model.splitDown(copyActiveItem: true)
    @command 'pane:close', =>
      @model.destroyItems()
      @model.destroy()
    @command 'pane:close-other-items', => @destroyInactiveItems()

  # Essential: Returns the {Pane} model underlying this pane view
  getModel: -> @model

  # Deprecated: Use ::destroyItem
  removeItem: (item) ->
    deprecate("Use PaneView::destroyItem instead")
    @destroyItem(item)

  # Deprecated: Use ::activateItem
  showItem: (item) ->
    deprecate("Use PaneView::activateItem instead")
    @activateItem(item)

  # Deprecated: Use ::activateItemForUri
  showItemForUri: (item) ->
    deprecate("Use PaneView::activateItemForUri instead")
    @activateItemForUri(item)

  # Deprecated: Use ::activateItemAtIndex
  showItemAtIndex: (index) ->
    deprecate("Use PaneView::activateItemAtIndex instead")
    @activateItemAtIndex(index)

  # Deprecated: Use ::activateNextItem
  showNextItem: ->
    deprecate("Use PaneView::activateNextItem instead")
    @activateNextItem()

  # Deprecated: Use ::activatePreviousItem
  showPreviousItem: ->
    deprecate("Use PaneView::activatePreviousItem instead")
    @activatePreviousItem()

  afterAttach: (onDom) ->
    @focus() if @model.focused and onDom

    return if @attached
    @container = @closest('.panes').view()
    @attached = true
    @trigger 'pane:attached', [this]

  onActivated: =>
    @focus() unless @hasFocus()

  onActiveStatusChanged: (active) =>
    if active
      @addClass('active')
      @trigger 'pane:became-active'
    else
      @removeClass('active')
      @trigger 'pane:became-inactive'

  # Public: Returns the next pane, ordered by creation.
  getNextPane: ->
    panes = @container?.getPaneViews()
    return unless panes.length > 1
    nextIndex = (panes.indexOf(this) + 1) % panes.length
    panes[nextIndex]

  getActivePaneItem: ->
    @activeItem

  onActiveItemChanged: (item) =>
    @activeItemDisposables.dispose() if @activeItemDisposables?
    @activeItemDisposables = new CompositeDisposable()

    if @previousActiveItem?.off?
      @previousActiveItem.off 'title-changed', @activeItemTitleChanged
      @previousActiveItem.off 'modified-status-changed', @activeItemModifiedChanged
    @previousActiveItem = item

    return unless item?

    if item.onDidChangeTitle?
      disposable = item.onDidChangeTitle(@activeItemTitleChanged)
      deprecate 'Please return a Disposable object from your ::onDidChangeTitle method!' unless disposable?.dispose?
      @activeItemDisposables.add(disposable) if disposable?.dispose?
    else if item.on?
      deprecate '::on methods for items are no longer supported. If you would like your item to title change behavior, please implement a ::onDidChangeTitle() method.'
      disposable = item.on('title-changed', @activeItemTitleChanged)
      @activeItemDisposables.add(disposable) if disposable?.dispose?

    if item.onDidChangeModified?
      disposable = item.onDidChangeModified(@activeItemModifiedChanged)
      deprecate 'Please return a Disposable object from your ::onDidChangeModified method!' unless disposable?.dispose?
      @activeItemDisposables.add(disposable) if disposable?.dispose?
    else if item.on?
      deprecate '::on methods for items are no longer supported. If you would like your item to support modified behavior, please implement a ::onDidChangeModified() method.'
      item.on('modified-status-changed', @activeItemModifiedChanged)
      @activeItemDisposables.add(disposable) if disposable?.dispose?

    view = @model.getView(item).__spacePenView
    otherView.hide() for otherView in @itemViews.children().not(view).views()
    @itemViews.append(view) unless view.parent().is(@itemViews)
    view.show() if @attached
    view.focus() if @hasFocus()

    @trigger 'pane:active-item-changed', [item]

  onItemAdded: ({item, index}) =>
    @trigger 'pane:item-added', [item, index]

  onItemRemoved: ({item, index, destroyed}) =>
    if item instanceof $
      viewToRemove = item
    else
      viewToRemove = @model.getView(item).__spacePenView

    if viewToRemove?
      if destroyed
        viewToRemove.remove()
      else
        viewToRemove.detach()

    @trigger 'pane:item-removed', [item, index]

  onItemMoved: ({item, newIndex}) =>
    @trigger 'pane:item-moved', [item, newIndex]

  onBeforeItemDestroyed: (item) =>
    @unsubscribe(item) if typeof item.off is 'function'
    @trigger 'pane:before-item-destroyed', [item]

  activeItemTitleChanged: =>
    @trigger 'pane:active-item-title-changed'

  activeItemModifiedChanged: =>
    @trigger 'pane:active-item-modified-status-changed'

  @::accessor 'activeView', -> @model.getView(@activeItem)?.__spacePenView

  splitLeft: (items...) -> @model.getView(@model.splitLeft({items})).__spacePenView

  splitRight: (items...) -> @model.getView(@model.splitRight({items})).__spacePenView

  splitUp: (items...) -> @model.getView(@model.splitUp({items})).__spacePenView

  splitDown: (items...) -> @model.getView(@model.splitDown({items})).__spacePenView

  # Public: Get the container view housing this pane.
  #
  # Returns a {View}.
  getContainer: ->
    @closest('.panes').view()

  beforeRemove: ->
    @subscriptions.dispose()
    @model.destroy() unless @model.isDestroyed()

  remove: (selector, keepData) ->
    return super if keepData
    @unsubscribe()
    super
