window.noflo = {} unless window.noflo
window.noflo.views = views = {}

class views.NetworkList extends Backbone.View
  app: null
  tagName: 'ul'
  className: 'thumbnails'

  initialize: (options) ->
    @app = options?.app
    @collection = options?.collection
    _.bindAll @, 'renderItems'
    @collection.bind 'reset add remove', @renderItems
    @

  render: ->
    @$el.empty()
    @renderItems()
    @

  renderItems: ->
    @collection.each @renderItem, @

  renderItem: (network) ->
    view = new views.NetworkListItem
      model: network
      app: @app
    @$el.append view.render().el

class views.NetworkListItem extends Backbone.View
  app: null
  template: '#NetworkListItem'
  tagName: 'li'
  className: 'span4'

  events:
    'click button.edit': 'editClicked'

  initialize: (options) ->
    @app = options?.app

  editClicked: ->
    @app.navigate "#network/#{@model.id}", true

  render: ->
    template = jQuery(@template).html()

    networkData = @model.toJSON()
    networkData.name = "Network #{@model.id}" unless networkData.name

    @$el.html _.template template, networkData
    @

class views.Network extends Backbone.View
  nodeViews: null
  edgeViews: null
  initialViews: null

  initialize: ->
    @nodeViews = {}
    @initialViews = []
    @edgeViews = []

    _.bindAll @, 'renderNodes', 'renderEdges'
    @model.get('nodes').bind 'reset', @renderNodes
    @model.get('edges').bind 'edges', @renderEdges

  render: ->
    @$el.empty()

    @renderNodes()
    @renderEdges()
    # TODO: Render legends

    @

  renderNodes: ->
    @model.get('nodes').each @renderNode, @

  renderEdges: ->
    @model.get('edges').each (edge) ->
      @renderInitial edge unless edge.get('from').node
      @renderEdge edge
    , @

  activate: ->
    @initializePlumb()
    _.each @nodeViews, (view) ->
      view.activate()
    _.each @initialViews, (view) ->
      view.activate()
    _.each @edgeViews, (view) ->
      view.activate()
    @bindPlumb()

  initializePlumb: ->
    # We need this for DnD
    document.onselectstart = -> false

    jsPlumb.Defaults.Connector = "Bezier"
    jsPlumb.Defaults.PaintStyle =
      strokeStyle: "#33B5E5"
      lineWidth: 3
    jsPlumb.Defaults.DragOptions =
      cursor: "pointer"
      zIndex: 2000
    jsPlumb.Defaults.ConnectionOverlays = [
      [ "PlainArrow" ]
    ]
    jsPlumb.setRenderMode jsPlumb.CANVAS

  bindPlumb: ->
    jsPlumb.bind 'jsPlumbConnection', (info) ->
      console.log "ATTACH", info
    jsPlumb.bind 'jsPlumbConnectionDetached', (info) =>
      for edgeView in @edgeViews
        continue unless edgeView.connection is info.connection
        console.log "DETACH", edgeView.model
        edgeView.model.destroy
          success: ->
            console.log "CONNECTION DELETED"
          error: ->
            console.log "FAILED TO DELETE CONNECTION"

  renderNode: (node) ->
    view = new views.Node
      model: node
      networkView: @
    @$el.append view.render().el
    @nodeViews[node.id] = view

  renderInitial: (edge) ->
    # IIP, render the data node as well
    iip = new window.noflo.models.Initial
      data: edge.get('from').data
      to: edge.get('to')
    view = new views.Initial
      model: iip
      networkView: @
    @$el.append view.render().el
    @initialViews.push view

  renderEdge: (edge) ->
    view = new views.Edge
      model: edge
      networkView: @
    view.render()
    @edgeViews.push view

class views.Node extends Backbone.View
  inAnchors: ["LeftMiddle", "TopLeft", "BottomLeft"]
  outAnchors: ["RightMiddle", "TopRight", "BottomRight"]
  inEndpoints: null
  outEndpoints: null
  template: '#Node'
  tagName: 'div'
  className: 'process'

  initialize: (options) ->
    @inEndpoints = {}
    @outEndpoints = {}

  render: ->
    @$el.attr 'id', @model.get 'cleanId'

    @$el.addClass 'subgraph' if @model.get 'subgraph'

    if @model.has 'display'
      @$el.css
        top: @model.get('display').x
        left: @model.get('display').y

    template = jQuery(@template).html()

    templateData = @model.toJSON()
    templateData.id = templateData.cleanId unless templateData.id

    @$el.html _.template template, templateData

    @model.get('inPorts').each @renderInport, @
    @model.get('outPorts').each @renderOutport, @
    @

  renderInport: (port, index) ->
    view = new views.Port
      model: port
      inPort: true
      nodeView: @
      anchor: @inAnchors[index]
    view.render()
    @inEndpoints[port.get('name')] = view

  renderOutport: (port, index) ->
    view = new views.Port
      model: port
      inPort: false
      nodeView: @
      anchor: @outAnchors[index]
    view.render()
    @outEndpoints[port.get('name')] = view

  activate: ->
    @makeDraggable()
    _.each @inEndpoints, (view) ->
      view.activate()
    _.each @outEndpoints, (view) ->
      view.activate()

  saveModel: ->
    @model.save()

class views.Initial extends Backbone.View
  tagName: 'div'
  className: 'initial'

  render: ->
    @$el.html @model.get 'data'
    @renderOutport()
    @

  renderOutport: ->
    view = new views.Port
      model: new window.noflo.models.Port
      inPort: false
      nodeView: @
      anchor: "RightMiddle"
    view.render()
    @outEndpoint = view

  activate: ->
    @makeDraggable()
    @outEndpoint.activate()

  saveModel: ->

class views.Port extends Backbone.View
  endPoint: null
  inPort: false
  anchor: "LeftMiddle"

  portDefaults:
    endpoint: [
      'Dot'
      radius: 6
    ]
    paintStyle:
      fillStyle: '#ffffff'

  initialize: (options) ->
    @endPoint = null
    @nodeView = options?.nodeView
    @inPort = options?.inPort
    @anchor = options?.anchor

  render: -> @

  activate: ->
    portOptions =
      isSource: true
      isTarget: false
      maxConnections: 1
      anchor: @anchor
      overlays: [
        [
          "Label"
            location: [2.5,-0.5]
            label: @model.get('name')
        ]
      ]
    if @inPort
      portOptions.isSource = false
      portOptions.isTarget = true
      portOptions.overlays[0][1].location = [-1.5, -0.5]
    if @model.get('type') is 'array'
      portOptions.endpoint = [
        'Rectangle'
        readius: 6
      ]
      portOptions.maxConnections = -1
    @endPoint = jsPlumb.addEndpoint @nodeView.el, portOptions, @portDefaults

class views.Edge extends Backbone.View
  networkView: null
  connection: null

  initialize: (options) ->
    @networkView = options?.networkView

  render: ->
    @

  activate: ->
    sourceDef = @model.get 'from'
    targetDef = @model.get 'to'

    if sourceDef.node
      source = @networkView.nodeViews[sourceDef.node].outEndpoints[sourceDef.port].endPoint
    else
      for initialView in @networkView.initialViews
        to = initialView.model.get 'to'
        continue unless to.node is targetDef.node and to.port is targetDef.port
        continue if initialView.outEndpoint.endPoint.isFull()
        source = initialView.outEndpoint.endPoint

    target = @networkView.nodeViews[targetDef.node].inEndpoints[targetDef.port].endPoint
    @connection = jsPlumb.connect
      source: source
      target: target

views.DraggableMixin =
  makeDraggable: ->
    jsPlumb.draggable @el,
      stop: (event, data) => @dragStop data
    @

  dragStop: (data) ->
    @model.set
      display:
        x: data.offset.top
        y: data.offset.left
    @saveModel()

_.extend views.Node::, views.DraggableMixin
_.extend views.Initial::, views.DraggableMixin
