import RecordView from '@/shared/record_store/record_view'
import RestfulClient from './restful_client'
import { snakeCase, isEmpty, camelCase, map, keys, each, intersection, merge, pick } from 'lodash'

export default class RecordStore
  constructor: (db) ->
    @db = db
    @collectionNames = []
    @views = {}
    @remote = new RestfulClient
    merge @remote, pick(@defaultRemoteCallbacks(), ['onPrepare', 'onSuccess', 'onUploadSuccess', 'onFailure', 'onCleanup'])

  fetch: (args) ->
    @remote.fetch(args)

  addRecordsInterface: (recordsInterfaceClass) ->
    recordsInterface = new recordsInterfaceClass(@)
    recordsInterface.setRemoteCallbacks(@defaultRemoteCallbacks())
    name = camelCase(recordsInterface.model.plural)
    @[name] = recordsInterface
    recordsInterface.onInterfaceAdded()
    @collectionNames.push name

  import: (data) ->
    return if isEmpty(data)

    # hack just to get around AMS
    if data['parent_groups']?
      each data['parent_groups'], (recordData) =>
        @groups.importJSON(recordData)
        true

    if data['parent_events']?
      each data['parent_events'], (recordData) =>
        @events.importJSON(recordData)
        true

    each @collectionNames, (name) =>
      snakeName = snakeCase(name)
      camelName = camelCase(name)
      if data[snakeName]?
        each data[snakeName], (recordData) =>
          @[camelName].importJSON(recordData)
          true

    @afterImport(data)

    each @views, (view) =>
      if intersection( map(view.collectionNames, camelCase) , map(keys(data), camelCase) )
        view.query(@)
      true
    data

  afterImport: (data) ->

  setRemoteCallbacks: (callbacks) ->
    each @collectionNames, (name) => @[camelCase(name)].setRemoteCallbacks(callbacks)

  defaultRemoteCallbacks: ->
    onUploadSuccess: (data) => @import(data)
    onSuccess: (response) =>
      if response.ok
        response.json().then (data) =>
          @import(data)
      else
        throw response
    onFailure: (response) =>
      throw response

  view: ({name, collections, query}) ->
    if !@views[name]
      @views[name] = new RecordView(name: name, recordStore: @, collections: collections, query: query)
    @views[name].query(@)
    @views[name]
