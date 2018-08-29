(function (root, factory) {
  if (typeof module === 'object' && module.exports) {
    module.exports = factory(require('jQuery'));
  } else {
    // Browser globals (root is window)
    root.RelationshipsDatatable = factory(root.jQuery, root.utility);
  }
}(this, function ($, utility) {

  // DOM HELPERS:
  var createElement = document.createElement.bind(document); // javascript! what a language!
  var createSelect = function(id) {
    return utility.createElement({ "tag": 'select', "class": 'form-control', "id": id });
  };

  var createOption = function(text, value) {
    var option = utility.createElementWithText('option', text);
    option.setAttribute('value', value);
    return option;
  };

  var createTextInput = function(id, placeholder) {
    var input = utility.createElement({ "tag": 'input', "id": id, "class": 'form-control' });
    input.setAttribute('type', 'text');
    input.setAttribute('placeholder', placeholder);
    return input;
  };

  var createCheckbox = function(id, text) {
    var label = utility.createElementWithText('label', text);
    label.setAttribute('for', id);
    var input = utility.createElement({ "tag": 'input', "id": id});
    input.setAttribute('type', 'checkbox');
    label.appendChild(input);
    return label;
  };

  var NUMBER_REGEX = RegExp('^[0-9]+$');
  
  var columns = ["Related Entity", "Relationship", "Details", "Date(s)"];
  var TABLE_ID = "relationships-table";
  var DEFAULT_OPTIONS = { isList: false };

  // Variables to hold fetched data and the entity initalized.
  // This is just a way to keep state without having to
  // deal with creating a javascript class
  var DATA_STORE = null;
  var ENTITY_ID = null;

  var DATATABLE_COLUMNS = [
    { 
      data: null,
      name: 'entity_name',
      width: '40%',
      render: renderRelatedEntity
    },
    {
      data: 'category_id',
      name: 'category',
      type: 'num',
      width: "10%",
      render: renderCategory
    },
    {
      name: 'description',
      render: renderDescription
    },
    {
      data: 'date',
      name: 'date',
      width: "15%",
      render: renderDate
    },
    {
      name: 'entity_types',
      data: null,
      visible: false,
      defaultConent: '',
      render: renderEntityTypes
    },
    {
      name: 'interlocks',
      data: null,
      visible: false,
      defaultConent: '',
      render: renderInterlocks
    },
    {
      data: 'amount',
      name: 'amount',
      visible: false,
    },
    {
      data: ternary('is_current'),
      name: 'is_current',
      visible: false
    },
    {
      data: ternary('is_board'),
      name: 'is_board',
      visible: false,
    },
    {
      data: ternary('is_executive'),
      name: 'is_executive',
      visible: false,
    }
  ];

  /**
   * Network request to obtain data for datatable
   *
   * @param {Integer} entityId
   * @returns {Promise} 
   */
  function fetchData(entityId) {
    return fetch("/datatable/entity/" + entityId, { "method": 'get' })
      .then(function(response) { return response.json(); });
  }

  /**
   * Returns the other entity id in the relationship
   *
   * @param {Object} relationship
   * @param {Object} other_entity_id
   */
  function otherEntity(relationship) {
    var entity_id = (relationship.entity1_id === ENTITY_ID) ? relationship.entity2_id : relationship.entity1_id;
    return DATA_STORE.entities[entity_id];
  };

  /////////////////////////////
  ///// RENDERING HELPERS /////
  /////////////////////////////

  // 
  // 

  /**
   * Used to handle searching of boolean columns
   * see: https://datatables.net/reference/option/columns.data
   * @param {String} key
   * @returns {Function} 
   */
  function ternary(key) {
    return function(row) {
      var value = row[key];
      if (value === true) {
	return "true";
      } else if (value === false) {
	return "false";
      } else {
	return 'null';
      }
    };
  }

  function renderEntityTypes(data) {
    return otherEntity(data).types.join(' ');
  }

  function renderInterlocks(data) {
    return data['interlocks'].join(' ');
  }

  /**
   * Render Link with Related Entity Names and Blurb
   * @returns {String} 
   */
  function renderRelatedEntity(data) {
    var entity = otherEntity(data);
    var a = utility.createLink(entity.url);
    a.setAttribute('class', 'entity-link');
    a.textContent = entity.name;
    
    if (entity.blurb) {
      // a.appendChild(createElement('br'));
      var blurb = utility.createElementWithText('div', entity.blurb);
      blurb.setAttribute('class', 'entity-blurb');
      a.appendChild(blurb);
    }
    
    return a.outerHTML;
  };


  /**
   * Renders description fields. Adds amount if present.
   *
   * @returns {String} 
   */
  function renderDescription(data, type, row) {
    if (ENTITY_ID === row.entity1_id) {
      return row.label_for_entity1;
    } else {
      return row.label_for_entity2;
    }
  };

  /**
   * Render link to Relationship
   *
   * @returns {String} 
   */
  function renderCategory(category_id, type, row) {
    var a = utility.createLink(row.url);
    a.textContent = utility.relationshipCategories[category_id];
    return a.outerHTML;
  };

  /**
   * Renders date or shows if relationship is current/past
   *
   * @returns {String|Null} 
   */
  function renderDate(data, type, row) {
    if (row.start_date && row.end_date) {
      if (row.start_date.slice(0, 4) === row.end_date.slice(0, 4)) {
	return row.start_date.slice(0, 4);
      } else {
	return row.start_date.slice(0, 4) + ' - ' + row.end_date.slice(0, 4);
      }
    }

    if (row.start_date && !row.end_date) {
      if (row.is_current === false) {
	return row.start_date.slice(0, 4) + ' (past)';
      } else {
	return row.start_date.slice(0, 4) + ' - ?';
      }
    }
    
    if (row.end_date) {
      return '? - ' + row.end_date.slice(0, 4);
    }

    if (row.is_current === true) {
      return "(current)";
    }

    if (row.is_current === false) {
      return "(past)";
    }
    return null;
  };


  // TABLE DOM ELEMENTS


  /*
   * These each return a single filter for the datatable
   */
  var filters = {

    "categories": function(categories) {
      var select = createSelect('relationships-category');

      [0].concat(categories).forEach(function(c) {
	var text = (c === 0) ? 'Category' : utility.relationshipCategories[c];
	var option = utility.createElementWithText('option', text);
	option.setAttribute('value', c);
	select.appendChild(option);
      });

      select.addEventListener('change', function(e) {
	tableApi()
	  .column('category:name')
	  .search(utility.relationshipCategories[this.value])
	  .draw();
      });
      
      return select;
    },

    "types": function(types) {
      var select = createSelect('relationships-type');

      [0].concat(types).forEach(function(t) {
	var text = (t === 0) ? 'Types' : utility.extensionDefinitions[t];
	var option = utility.createElementWithText('option', text);
	option.setAttribute('value', t);
	select.appendChild(option);
      });
      

      select.addEventListener('change', function(e) {
	var query = (Number(this.value) === 0) ? '' : ('\\b' + this.value + '\\b');
	
	tableApi()
	  .column('entity_types:name')
	  .search(query, true, false)
	  .draw();
      });
      
      return select;

    },

    "interlocks": function(interlocks) {
      var select = createSelect('relationships-interlocks');
      select.appendChild(createOption('Connected To', 0));

      interlocks.forEach(function(interlock) {
	select.appendChild(createOption(
	  interlock.name + ' (' + interlock.interlocks_count + ')',
	  interlock.id
	));
      });

      select.addEventListener('change', function(e) {
	var query = (Number(this.value) === 0) ? '' : ('\\b' + this.value + '\\b');
	tableApi()
	  .column('interlocks:name')
	  .search(query, true, false)
	  .draw();
      });
      return select;
    },

    "search": function() {
      var input = createTextInput('relationships-search', 'search');

      input.addEventListener('keyup', function(e) {
	tableApi().search(this.value).draw();
      });
      
      return input;
    },

    // see: https://stackoverflow.com/questions/29836857/jquery-datatable-filtering-so-confusing
    //       and https://datatables.net/examples/plug-ins/range_filtering
  
    "amount": function() {
      var input = createTextInput('relationships-amount', 'min amount');

      input.addEventListener('keyup', function(e) {
	// if the input is not an integer
	// clear the search and return early
	if (!NUMBER_REGEX.test(this.value.trim())) {
	  $.fn.dataTable.ext.search.pop();
	  tableApi().draw();
	  return;
	}
	
	var minimumAmount = Number(this.value.trim());

	$.fn.dataTable.ext.search.push(
	  function(settings, data, dataIndex) {
	    if (NUMBER_REGEX.test(data[6])) {
	      return Number(data[6]) >= minimumAmount;
	    } else {
	      return false;
	    }
	  }
	);
	tableApi().draw();
	$.fn.dataTable.ext.search.pop();
      });

      return input;
    },

    "isCurrent": function() {
      var checkbox = createCheckbox('relationships-current', 'Current');

      checkbox.querySelector('input').addEventListener('change', function(e) {
	var query = this.checked ? 'true' : '';
	tableApi().column('is_current:name').search(query).draw();
      });
      
      return checkbox;
    },

    "isBoard": function() {
      var checkbox = createCheckbox('relationships-board', 'Board Member');

      checkbox.querySelector('input').addEventListener('change', function(e) {
	var query = this.checked ? 'true' : '';
	tableApi().column('is_board:name').search(query).draw();
      });
      
      return checkbox;
    },

    "isExecutive": function() {
      var checkbox = createCheckbox('relationships-executive', 'Executive');

      checkbox.querySelector('input').addEventListener('change', function(e) {
	var query = this.checked ? 'true' : '';
	tableApi().column('is_executive:name').search(query).draw();
      });
      
      return checkbox;
    }
  };


  /**
   * Creates table filters
   *
   * @param {Object} data
   * @returns {Element} 
   */
  function createFilters(data) {
    var div = utility.createElement({ "id": 'relationships-filters', "class": 'form-inline' });

    ['categories', 'types', 'interlocks'].forEach(function(filter) {
      div.appendChild(filters[filter](data[filter]));
    });

    var line2 = utility.createElement({ "id": 'relationships-filters-line2' });

    ['search', 'amount', 'isCurrent', 'isBoard', 'isExecutive'].forEach(function(filter) {
      line2.appendChild(filters[filter]());
    });
    
    div.appendChild(line2);
    return div;
  }

  /**
   * Creates a <table> with column headers
   *
   * @returns {Element} 
   */
  function createTable() {
    var table = createElement('table');
    table.className = "display";
    table.id = TABLE_ID;

    var thead = createElement('thead');
    var tr = createElement('tr');

    columns.forEach(function(c) {
      tr.appendChild(utility.createElementWithText('th', c));
    });
    
    thead.appendChild(tr);
    table.appendChild(thead);
    return table;
  }

  function setupDom(data) {
    var container = document.getElementById('relationships-datatable-container');
    container.appendChild( createFilters(data) );
    container.appendChild( createTable() );
  }

  // MAIN //
  
  function tableApi() {
    return $('#' + TABLE_ID).dataTable().api();
  }

  /**
   * Main function that initializes the table
   *
   * @param {Array[object]} data
   */
  function datatable() {
    $('#' + TABLE_ID).DataTable({
      "data": DATA_STORE.relationships,
      "dom": 'prtp',
      // dom: "<'buttons'>iprtp",
      "pageLength": 100,
      "columns": DATATABLE_COLUMNS
    });

  }

  function start(entityId) {
    ENTITY_ID = entityId;
    fetchData(entityId)
      .then(function(data) {
	DATA_STORE = data;
	setupDom(data);
	datatable();
      });

  }

  return {
    "start": start,
    "tableApi": tableApi,
    "data": function() { return DATA_STORE; }
  };
  
  
}));
