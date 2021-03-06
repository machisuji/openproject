//-- copyright
// OpenProject is a project management system.
// Copyright (C) 2012-2015 the OpenProject Foundation (OPF)
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License version 3.
//
// OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
// Copyright (C) 2006-2013 Jean-Philippe Lang
// Copyright (C) 2010-2013 the ChiliProject Team
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
//
// See doc/COPYRIGHT.rdoc for more details.
//++

module.exports = function($window, $rootScope, $timeout, PathHelper) {

  // modalHelperInstance
  // Mousetrap
  // TODO: globals, should be wrapped in .constant

  var accessKeys = {
    preview: 1,
    newWorkPackage: 2,
    edit: 3,
    quickSearch: 4,
    projectSearch: 5,
    help: 6,
    moreMenu: 7,
    details: 8
  };

  // maybe move it to a .constant
  var shortcuts = {
    '?': showHelpModal,
    'up up down down left right left right b a enter': showHelpModal,
    'g m': 'staticMyPagePath',
    'g o': projectScoped('staticProjectPath'),
    'g w p': projectScoped('staticProjectWorkPackagesPath'),
    'g w i': projectScoped('staticProjectWikiPath'),
    'g a': projectScoped('activityFromPath'),
    'g c': projectScoped('staticProjectCalendarPath'),
    'g n': projectScoped('staticProjectNewsPath'),
    'g t': projectScoped('staticProjectTimelinesPath'),
    'n w p': projectScoped('staticWorkPackageNewWithParametersPath'),

    'g e': accessKey('edit'),
    'g p': accessKey('preview'),
    'd w p': accessKey('details'),
    'm': accessKey('moreMenu'),
    'p': accessKey('projectSearch'),
    's': accessKey('quickSearch'),
    'k': focusPrevItem,
    'j': focusNextItem
  };

  function accessKey(keyName) {
    var key = accessKeys[keyName];
    return function() {
      var elem = angular.element('[accesskey=' + key + ']:first');
      if (elem.is('input')) {
        // timeout with delay so that the key is not
        // triggered on the input
        $timeout(function() {
          elem.focus();
        });
      } else {
        elem.click();
      }
    };
  }

  function projectScoped(action) {
    return function() {
      var projectIdentifier = $rootScope.projectIdentifier;
      if (projectIdentifier) {
        var url = PathHelper[action](projectIdentifier);
        $window.location.href = url;
      }
    };
  }

  function showHelpModal() {
    modalHelperInstance.createModal(PathHelper.staticKeyboardShortcutsHelpPath());
  }

  // this could be extracted into a separate component if it grows
  var accessibleListSelector = 'table.list, table.keyboard-accessible-list';
  var accessibleRowSelector = 'table.list tr, table.keyboard-accessible-list tr';

  function findListInPage() {
    var domLists, focusElements;
    focusElements = [];
    domLists = angular.element(accessibleListSelector);
    domLists.find('tbody tr').each(function(index, tr){
      var firstLink = angular.element(tr).find('a:visible:not(.toggle-all)')[0];
      if ( firstLink !== undefined ) { focusElements.push(firstLink); }
    });
    return focusElements;
  }

  function focusItemOffset(offset) {
    var list, index;
    list = findListInPage();
    if (list === null) { return; }
    index = list.indexOf(
      angular
        .element(document.activeElement)
        .parents(accessibleRowSelector)
        .find('a:visible')[0]
    );
    angular.element(list[(index+offset+list.length) % list.length]).focus();
  }

  function focusNextItem() {
    focusItemOffset(1);
  }

  function focusPrevItem() {
    focusItemOffset(-1);
  }

  var KeyboardShortcutService = {
    activate: function() {

      _.forEach(shortcuts, function(action, key) {
        if (_.isFunction(action)) {
          Mousetrap.bind(key, action);
        } else {
          Mousetrap.bind(key, function() {
            var url = PathHelper[action]();
            $window.location.href = url;
          });
        }
      });
    }
  };

  return KeyboardShortcutService;
};
