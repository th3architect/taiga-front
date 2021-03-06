###
# Copyright (C) 2014 Andrey Antukh <niwi@niwi.be>
# Copyright (C) 2014 Jesús Espino Garcia <jespinog@gmail.com>
# Copyright (C) 2014 David Barragán Merino <bameda@dbarragan.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.
#
# File: modules/wiki/detail.coffee
###

taiga = @.taiga

mixOf = @.taiga.mixOf
groupBy = @.taiga.groupBy
bindOnce = @.taiga.bindOnce
slugify = @.taiga.slugify
unslugify = @.taiga.slugify

module = angular.module("taigaWiki")


#############################################################################
## Wiki Main Directive
#############################################################################

WikiNavDirective = ($tgrepo, $log, $location, $confirm, $navUrls, $analytics, $loading) ->
    template = _.template("""
    <header>
      <h1>Links</h1>
    </header>
    <nav>
      <ul>
        <% _.each(wikiLinks, function(link, index) { %>
        <li class="wiki-link" data-id="<%- index %>">
          <a title="<%- link.title %>">
              <span class="link-title"><%- link.title %></span>
              <% if (deleteWikiLinkPermission) { %>
              <span class="icon icon-delete"></span>
              <% } %>
          </a>
          <input type="text" placeholder="name" class="hidden" value="<%- link.title %>" />
        </li>
        <% }) %>
        <li class="new hidden">
          <input type="text" placeholder="name"/>
        </li>
      </ul>
    </nav>
    <% if (addWikiLinkPermission) { %>
    <a href="" title="Add link" class="add-button button button-gray">Add link</a>
    <% } %>
    """)
    link = ($scope, $el, $attrs) ->
        $ctrl = $el.controller()

        if not $attrs.ngModel?
            return $log.error "WikiNavDirective: no ng-model attr is defined"

        render = (wikiLinks) ->
            addWikiLinkPermission = $scope.project.my_permissions.indexOf("add_wiki_link") > -1
            deleteWikiLinkPermission = $scope.project.my_permissions.indexOf("delete_wiki_link") > -1

            html = template({
                wikiLinks: wikiLinks,
                projectSlug: $scope.projectSlug
                addWikiLinkPermission: addWikiLinkPermission
                deleteWikiLinkPermission: deleteWikiLinkPermission
            })

            $el.off()
            $el.html(html)

            $el.on "click", ".wiki-link .link-title", (event) ->
                event.preventDefault()
                target = angular.element(event.currentTarget)
                linkId = target.parents('.wiki-link').data('id')
                linkSlug = $scope.wikiLinks[linkId].href
                $scope.$apply ->
                    ctx = {
                        project: $scope.projectSlug
                        slug: linkSlug
                    }
                    $location.path($navUrls.resolve("project-wiki-page", ctx))

            $el.on "click", ".add-button", (event) ->
                event.preventDefault()
                $el.find(".new").removeClass("hidden")
                $el.find(".new input").focus()
                $el.find(".add-button").hide()

            $el.on "click", ".wiki-link .icon-delete", (event) ->
                event.preventDefault()
                event.stopPropagation()
                target = angular.element(event.currentTarget)
                linkId = target.parents('.wiki-link').data('id')

                # TODO: i18n
                title = "Delete Wiki Link"
                message = $scope.wikiLinks[linkId].title

                $confirm.askOnDelete(title, message).then (finish) =>
                    promise = $tgrepo.remove($scope.wikiLinks[linkId])
                    promise.then ->
                        promise = $ctrl.loadWikiLinks()
                        promise.then ->
                            finish()
                            render($scope.wikiLinks)
                        promise.then null, ->
                            finish()
                    promise.then null, ->
                        finish(false)
                        $confirm.notify("error")

            $el.on "keyup", ".new input", (event) ->
                event.preventDefault()
                if event.keyCode == 13
                    target = angular.element(event.currentTarget)
                    newLink = target.val()

                    $loading.start($el.find(".new"))

                    promise = $tgrepo.create("wiki-links", {project: $scope.projectId, title: newLink, href: slugify(newLink)})
                    promise.then ->
                        $analytics.trackEvent("wikilink", "create", "create wiki link", 1)
                        loadPromise = $ctrl.loadWikiLinks()
                        loadPromise.then ->
                            $loading.finish($el.find(".new"))
                            $el.find(".new").addClass("hidden")
                            $el.find(".new input").val('')
                            $el.find(".add-button").show()
                            render($scope.wikiLinks)
                        loadPromise.then null, ->
                            $loading.finish($el.find(".new"))
                            $el.find(".new").addClass("hidden")
                            $el.find(".new input").val('')
                            $el.find(".add-button").show()
                            $confirm.notify("error", "Error loading wiki links")

                    promise.then null, (error) ->
                        $loading.finish($el.find(".new"))
                        $el.find(".new input").val(newLink)
                        $el.find(".new input").focus().select()
                        if error?.__all__?[0]?
                            $confirm.notify("error", "The link already exists")
                        else
                            $confirm.notify("error")

                else if event.keyCode == 27
                    target = angular.element(event.currentTarget)
                    $el.find(".new").addClass("hidden")
                    $el.find(".new input").val('')
                    $el.find(".add-button").show()


        bindOnce($scope, $attrs.ngModel, render)

    return {link:link}

module.directive("tgWikiNav", ["$tgRepo", "$log", "$tgLocation", "$tgConfirm", "$tgNavUrls",
                               "$tgAnalytics", "$tgLoading", WikiNavDirective])
