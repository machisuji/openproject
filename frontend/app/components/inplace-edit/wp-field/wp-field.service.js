// -- copyright
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
// ++

angular
  .module('openproject.services')
  .service('WorkPackageFieldService', WorkPackageFieldService);

function WorkPackageFieldService($q, $http, $filter, I18n,  WorkPackagesHelper, HookService,
  inplaceEditErrors) {

  function getSchema(workPackage) {
    if (workPackage.form) {
      return workPackage.form.embedded.schema;
    } else {
      return workPackage.schema;
    }
  }

  function getFieldSchema(workPackage, field) {
    var schema = getSchema(workPackage);
    return schema.props[field];
  }

  function isEditable(workPackage, field) {
    // no form - no editing
    if (!workPackage.form) {
      return false;
    }
    var schema = getSchema(workPackage);
    // TODO: extract to strategy if new cases arise
    if (field === 'date') {
      // nope
      return schema.props['startDate'].writable && schema.props['dueDate'].writable;
      //return workPackage.schema.props.startDate.writable
      // && workPackage.schema.props.dueDate.writable;
    }
    if(schema.props[field].type === 'Date') {
      return true;
    }
    var isWritable = schema.props[field].writable;

    // not writable if no embedded allowed values
    if (isWritable && schema.props[field]._links && allowedValuesEmbedded(workPackage, field)) {
      isWritable = getEmbeddedAllowedValues(workPackage, field).length > 0;
    }

    return isWritable;
  }

  function isSpecified(workPackage, field) {
    var schema = getSchema(workPackage);
    if (field === 'date') {
      // kind of specified
      return true;
    }
    return !_.isUndefined(schema.props[field]);
  }

  // under special conditions fields will be shown
  // irregardless if they are empty or not
  // e.g. when an error should trigger the editing state
  // of an empty field after type change
  function isHideable(workPackage, field) {
    if (inplaceEditErrors.errors && inplaceEditErrors.errors[field]) {
      return false;
    }

    var attrVisibility = getVisibility(workPackage, field);

    var notRequired = !isRequired(workPackage, field) || hasDefault(workPackage, field);
    var empty = isEmpty(workPackage, field);
    var visible = attrVisibility == 'visible'; // always show
    var hidden = attrVisibility == 'hidden'; // never show
    // not hidden and not visible => show if not empty (default)

    return notRequired && !visible && (empty || hidden);
  }

  function getVisibility(workPackage, field) {
    if (field == "date") {
      return getDateVisibility(workPackage);
    } else {
      var schema = workPackage.form.embedded.schema;
      var prop = schema && schema.props && schema.props[field];

      return prop && prop.visibility;
    }
  }

  /**
   * There isn't actually a 'date' field for work packages.
   * There are two fields: 'start_date' and 'due_date'
   * Though they are displayed together in one row, as one 'field'.
   * Since the schema doesn't know any field named 'date' we
   * derive the visibility for the imaginary 'date' field from
   * the actual schema values of 'due_date' and 'start_date'.
   *
   * 'visible' > 'default' > 'hidden'
   * Meaning, for instance, that if at least one field is 'visible'
   * both will be shown. Even if the other is 'hidden'.
   *
   * Note: this is duplicated in app/views/types/_form.html.erb
   */
  function getDateVisibility(workPackage) {
    var a = getVisibility(workPackage, "startDate");
    var b = getVisibility(workPackage, "dueDate");
    var values = [a, b];

    if (_.contains(values, "visible")) {
      return "visible";
    } else if (_.contains(values, "default")) {
      return "default";
    } else if (_.contains(values, "hidden")) {
      return "hidden";
    } else {
      return undefined;
    }
  }

  function isMilestone(workPackage) {
    // TODO: this should be written as "only use the form when editing"
    // otherwise always use the simple way
    // currently we don't know the context in which this method is called
    var formAvailable = !_.isUndefined(workPackage.form);
    if (formAvailable) {
      var embedded = workPackage.form.embedded,
        allowedValues = embedded.schema.props.type._embedded.allowedValues,
        currentType = embedded.payload.links.type.props.href;
      return _.some(allowedValues, function(allowedValue) {
        return allowedValue._links.self.href === currentType &&
          allowedValue.isMilestone;
      });
    } else {
      return workPackage.embedded.type.isMilestone;
    }
  }

  function getValue(workPackage, field, isReadMode) {
    var embedded = !isReadMode && workPackage.form && workPackage.form.embedded.payload;
    var payload = embedded || workPackage;

    if (field === 'date') {
      if(isMilestone(workPackage)) {
        return payload.props['dueDate'];
      }
      return {
        startDate: payload.props['startDate'],
        dueDate: payload.props['dueDate']
      };
    }
    if (!_.isUndefined(payload.props[field])) {
      return payload.props[field];
    }
    if (WorkPackageFieldService.isEmbedded(payload, field)) {
      return payload.embedded[field];
    }

    if (payload.links[field] && payload.links[field].props.href !== null) {
      return payload.links[field];
    }
    return null;
  }

  function allowedValuesEmbedded(workPackage, field) {
    var schema = getSchema(workPackage);
    return _.isArray(schema.props[field]._links.allowedValues);
  }

  function getEmbeddedAllowedValues(workPackage, field) {
    var options = [];
    var schema = getSchema(workPackage);
    return schema.props[field]._embedded.allowedValues;
  }

  function getLinkedAllowedValues(workPackage, field) {
    var schema = getSchema(workPackage);
    var href = schema.props[field]._links.allowedValues.href;
    return $http.get(href).then(function(r) {
      var options = [];
      options = _.map(r.data._embedded.elements, function(item) {
        return _.extend({}, item._links.self, { name: item.name, props: { href: item._links.self.href } });
      });
      return options;
    });
  }

  function getAllowedValues(workPackage, field) {
    if (allowedValuesEmbedded(workPackage, field)) {
      return $q(function(resolve) {
        resolve(getEmbeddedAllowedValues(workPackage, field));
      });
    } else {
      return getLinkedAllowedValues(workPackage, field);
    }
  }

  function isRequired(workPackage, field) {
    var schema = getSchema(workPackage);
    if (_.isUndefined(schema.props[field])) {
      return false;
    }
    return schema.props[field].required;
  }

  function hasDefault(workPackage, field) {
    var schema = getSchema(workPackage);
    if (_.isUndefined(schema.props[field])) {
      return false;
    }
    return schema.props[field].hasDefault;
  }

  function isEmbedded(workPackage, field) {
    return !_.isUndefined(workPackage.embedded[field]);
  }

  function isSavedAsLink(workPackage, field) {
    return _.isUndefined(workPackage.form.embedded.payload.props[field]);
  }

  function getLabel(workPackage, field) {
    var schema = getSchema(workPackage);
    if (field === 'date') {
      // special case
      return I18n.t('js.work_packages.properties.date');
    }
    return schema.props[field].name;
  }

  function getKeyValue(workPackage, field) {
    var label = getLabel(workPackage, field);
    var value = WorkPackageFieldService.format(workPackage, field);

    if (value === null) {
      value = I18n.t('js.work_packages.no_value');
    }
    else if (value && value.raw) {
      var shortened = value.raw.length > 20;

      value = $filter('limitTo')(value.raw, 20);
      if (shortened) {
        value += '...';
      }
    }
    else if(value && value.props && value.props.name) {
      value = value.props.name;
    }
    else if(value && value.props && value.props.subject) {
      value = value.props.subject;
    }
    else if(field === 'date' && !isMilestone(workPackage)) {
      value = (value.startDate || I18n.t('js.label_no_start_date')) + ' - ' +
        (value.dueDate || I18n.t('js.label_no_due_date'));
    }

    return I18n.t('js.work_packages.key_value', { key: label, value: value });
  }

  function isEmpty(workPackage, field) {
    if (field === 'date') {
      return (
        getValue(workPackage, 'startDate') === null &&
        getValue(workPackage, 'dueDate') === null
      );
    }
    var value = WorkPackageFieldService.format(workPackage, field);
    if (value === null || value === '') {
      return true;
    }

    if (value.html === '') {
      return true;
    }

    if (field === 'spentTime' && workPackage.props[field] === 'PT0S') {
      return true;
    }

    if (value.embedded && _.isArray(value.embedded.elements)) {
      return value.embedded.elements.length === 0;
    }

    return false;
  }

  function getInplaceEditStrategy(workPackage, field) {
    var schema = getSchema(workPackage);
    var fieldType = null,
        inplaceType = 'text';

    if (field === 'date') {
      if(isMilestone(workPackage)) {
        fieldType = 'Date';
      } else {
        fieldType = 'DateRange';
      }
    } else {
      fieldType = schema.props[field].type;
    }
    switch(fieldType) {
      case 'DateRange':
        inplaceType = 'date-range';
        break;
      case 'Date':
        inplaceType = 'date';
        break;
      case 'Float':
        inplaceType = 'float';
        break;
      case 'Integer':
        inplaceType = 'integer';
        break;
      case 'Boolean':
        inplaceType = 'boolean';
        break;
      case 'Formattable':
        if (workPackage.form.embedded.payload.props[field].format === 'textile') {
          inplaceType = 'wiki-textarea';
        } else {
          inplaceType = 'textarea';
        }
        break;
      case 'Duration':
        inplaceType = 'duration';
        break;
      case 'Type':
        inplaceType = 'type';
        break;
      case 'StringObject':
      case 'User':
      case 'Status':
      case 'Priority':
      case 'Project':
      case 'Category':
      case 'Version':
        inplaceType = 'drop-down';
        break;
    }

    var typeFromPluginHook = HookService.call('workPackageAttributeEditableType', {
      type: fieldType
    }).pop();

    if (typeFromPluginHook) {
      inplaceType = typeFromPluginHook;
    }
    return inplaceType;
  }

  function getInplaceDisplayStrategy(workPackage, field) {
    var schema = getSchema(workPackage);
    var fieldType = null,
      displayStrategy = 'embedded';

    if (field === 'date') {
      if(isMilestone(workPackage)) {
        fieldType = 'Date';
      } else {
        fieldType = 'DateRange';
      }
    } else if (field === 'spentTime') {
      fieldType = 'SpentTime';
    }  else {
      fieldType = schema.props[field].type;
    }
    switch(fieldType) {
      case 'String':
      case 'Integer':
      case 'Float':
      case 'Duration':
      case 'Boolean':
        displayStrategy = 'text';
        break;
      case 'SpentTime':
        displayStrategy = 'spent-time';
        break;
      case 'Formattable':
        displayStrategy = 'wiki-textarea';
        break;
      case 'Version':
        displayStrategy = 'version';
        break;
      case 'User':
        displayStrategy = 'user';
        break;
      case 'DateRange':
        displayStrategy = 'date-range';
        break;
      case 'Date':
        displayStrategy = 'date';
        break;
    }

    //workPackageOverviewAttributes
    var pluginDirectiveName = HookService.call('workPackageOverviewAttributes', {
      type: fieldType,
      field: field,
      workPackage: workPackage
    })[0];
    if (pluginDirectiveName) {
      displayStrategy = 'dynamic';
    }

    return displayStrategy;
  }

  function format(workPackage, field) {
    var schema = getSchema(workPackage);
    if (field === 'date') {
      if(isMilestone(workPackage)) {
        return workPackage.props['dueDate'];
      }
      return {
        startDate: workPackage.props.startDate,
        dueDate: workPackage.props.dueDate,
        noStartDate: I18n.t('js.label_no_start_date'),
        noEndDate: I18n.t('js.label_no_due_date')
      };
    }

    var value = workPackage.props[field];
    if (_.isUndefined(value)) {
      return WorkPackageFieldService.getValue(workPackage, field, true);
    }

    if (value === null) {
      return null;
    }

    var fieldMapping = {
      dueDate: 'date',
      startDate: 'date',
      createdAt: 'datetime',
      updatedAt: 'datetime'
    }[field] || schema.props[field].type;

    switch(fieldMapping) {
      case('Duration'):
        var hours = moment.duration(value).asHours();
        var formattedHours = $filter('number')(hours, 2);
        return I18n.t('js.units.hour', { count: formattedHours });
      case('Boolean'):
        return value ? I18n.t('js.general_text_yes') : I18n.t('js.general_text_no');
      case('Date'):
        return value;
      case('Float'):
        return $filter('number')(value);
      default:
        return WorkPackagesHelper.formatValue(value, fieldMapping);
    }
  }

  var WorkPackageFieldService = {
    getSchema: getSchema,
    getFieldSchema: getFieldSchema,
    isEditable: isEditable,
    isRequired: isRequired,
    isSpecified: isSpecified,
    isEmpty: isEmpty,
    isHideable: isHideable,
    isMilestone: isMilestone,
    isEmbedded: isEmbedded,
    isSavedAsLink: isSavedAsLink,
    getValue: getValue,
    getLabel: getLabel,
    getKeyValue: getKeyValue,
    getAllowedValues: getAllowedValues,
    allowedValuesEmbedded: allowedValuesEmbedded,
    format: format,
    getInplaceEditStrategy: getInplaceEditStrategy,
    getInplaceDisplayStrategy: getInplaceDisplayStrategy
  };

  return WorkPackageFieldService;
}
