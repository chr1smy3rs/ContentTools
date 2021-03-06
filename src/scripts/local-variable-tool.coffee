class LocalVariableTool extends ContentTools.Tools.Bold

  # Insert/Remove a <local-variable> tag.

  # Register the tool with the toolshelf
  ContentTools.ToolShelf.stow(@, 'local-variable')

  # The tooltip and icon modifier CSS class for the tool
  @label = 'Local Variable'
  @icon = 'local-variable'

  # The Bold provides a tagName attribute we can override to make inheriting
  # from the class cleaner.
  @tagName = 'local-variable'

  @canApply: (element, selection) ->
# Return true if the tool can be applied to the current
# element/selection.
    if(Object.keys(localVariables).length == 0)
      return false

    return super(element, selection)

  @apply: (element, selection, callback) ->
# Apply a <local-variable> element to the specified element and selection

# Store the selection state of the element so we can restore it once done
    element.storeState()

    # Add a fake selection wrapper to the selected text so that it appears to be
    # selected when the focus is lost by the element.
    selectTag = new HTMLString.Tag('span', {'class': 'ct--puesdo-select'})
    [from, to] = selection.get()
    element.content = element.content.format(from, to, selectTag)
    element.updateInnerHTML()

    # Set-up the dialog
    app = ContentTools.EditorApp.get()

    # Add an invisible modal that we'll use to detect if the user clicks away
    # from the dialog to close it.
    modal = new ContentTools.ModalUI(transparent=true, allowScrolling=true)

    modal.addEventListener 'click', () ->

      # Close the dialog
      @unmount()
      dialog.hide()

      # Remove the fake selection from the element
      element.content = element.content.unformat(from, to, selectTag)
      element.updateInnerHTML()

      # Restore the real selection
      element.restoreState()

      # Trigger the callback
      callback(false)

    # Measure a rectangle of the content selected so we can position the
    # dialog centrally to it.
    domElement = element.domElement()
    measureSpan = domElement.getElementsByClassName('ct--puesdo-select')
    rect = measureSpan[0].getBoundingClientRect()

    # Create the dialog
    dialog = new LocalVariableDialog(@getValue(element, selection))
    dialog.position([
      rect.left + (rect.width / 2) + window.scrollX,
      rect.top + (rect.height / 2) + window.scrollY
    ])

    # Listen for save events against the dialog
    dialog.addEventListener 'save', (ev) ->
# Add/Update/Remove the <local-variable>
      value = ev.detail().value

      # Clear any existing link
      element.content = element.content.unformat(from, to, 'local-variable')

      # If specified add the new local-variable
      if value
        localVariable = localVariables[value]
        tooltip = value + ' (' + (localVariable['format'] || localVariable['type']) + ')'
        localVariableTag = new HTMLString.Tag('local-variable', {value: value, tooltip: tooltip})
        element.content = element.content.format(from, to, localVariableTag)

      element.updateInnerHTML()
      element.taint()

      # Close the modal and dialog
      modal.unmount()
      dialog.hide()

      # Remove the fake selection from the element
      element.content = element.content.unformat(from, to, selectTag)
      element.updateInnerHTML()

      # Restore the real selection
      element.restoreState()

      # Trigger the callback
      callback(true)

    app.attach(modal)
    app.attach(dialog)
    modal.show()
    dialog.show()


  @getValue: (element, selection) ->
# Find the first character in the selected text that has a `local-variable` tag and
# return its `value` value.
    [from, to] = selection.get()
    selectedContent = element.content.slice(from, to)
    for c in selectedContent.characters

# Does this character have a local-variable tag applied?
      if not c.hasTags('local-variable')
        continue

      # Find the local-variable tag and return the value attribute value
      for tag in c.tags()
        if tag.name() == 'local-variable'
          return tag.attr('value')

      return ''

# @getCommonName: (element, selection) ->
# Return any existing `common-name` attribute for the element and selection

class LocalVariableDialog extends ContentTools.AnchoredDialogUI

  # An anchored dialog to support inserting/modifying a local variable

  constructor: (value='') ->
    super()

    # The initial value is the variable name.
    @_value=value

  mount: () ->
# Mount the widget
    super()

    # Create the input element for the link
    @_domSelect = document.createElement('select')
    @_domSelect.setAttribute('class', 'ct-local-variable-dialog__input')
    @_domSelect.setAttribute('name', 'value')
    for own attr, info of localVariables
      tooltip = info['format'] || info['type']
      domOptionText = document.createTextNode(attr + ' (' + tooltip + ')')
      domOption = document.createElement('option')
      domOption.setAttribute('value', attr)
      if attr == @_value
        domOption.setAttribute('selected', 'true')
      domOption.appendChild(domOptionText)
      @_domSelect.appendChild(domOption)

    @_domElement.appendChild(@_domSelect)

    # Create the confirm button
    @_domButton = @constructor.createDiv(['ct-local-variable-dialog__button'])
    @_domElement.appendChild(@_domButton)

    # Add interaction handlers
    @_addDOMEventListeners()

  save: () ->
# Save the link. This method triggers the save method against the dialog
# allowing the calling code to listen for the `save` event and manage
# the outcome.

    if not @isMounted()
      @dispatchEvent(@createEvent('save'))
      return

    detail = {value: @_domSelect.value.trim()}

    @dispatchEvent(@createEvent('save', detail))

  show: () ->
# Show the widget
    super()

    # Once visible automatically give focus to the link input
    @_domSelect.focus()

  unmount: () ->
# Unmount the component from the DOM

# Unselect any content
    if @isMounted()
      @_domSelect.blur()

    super()

    @_domButton = null
    @_domSelect = null

# Private methods

  _addDOMEventListeners: () ->
# Add event listeners for the widget

# Add support for saving the link whenever the `return` key is pressed
# or the button is selected.

# Input
    @_domSelect.addEventListener 'keypress', (ev) =>
      if ev.keyCode is 13
        @save()

    # Button
    @_domButton.addEventListener 'click', (ev) =>
      ev.preventDefault()
      @save()

ContentTools.DEFAULT_TOOLS[0].push('local-variable')