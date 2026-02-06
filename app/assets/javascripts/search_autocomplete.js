// jQuery UI Autocomplete for Search Field - Server-side
(function () {
    'use strict';

    let isInitializing = false;

    function initializeAutocomplete() {
        console.log('Initializing server-side autocomplete...');

        // Prevent multiple initializations
        if (isInitializing) {
            console.log('Already initializing, skipping...');
            return;
        }

        isInitializing = true;

        const $searchField = $('#search-field-header');
        if (!$searchField.length) {
            console.error('Search field not found!');
            isInitializing = false;
            return;
        }

        console.log('Search field found');

        // Destroy existing autocomplete if it exists
        if ($searchField.data("ui-autocomplete")) {
            console.log('Destroying existing autocomplete instance');
            $searchField.autocomplete("destroy");
        }

        setupAutocomplete($searchField);
        isInitializing = false;
    }

    function setupAutocomplete($searchField) {
        console.log('Setting up server-side autocomplete');

        // Initialize jQuery UI Autocomplete with server-side source
        $searchField.autocomplete({
            source: function (request, response) {
                console.log('Fetching suggestions for:', request.term);

                $.ajax({
                    url: '/autocomplete/titles',
                    dataType: 'json',
                    data: {
                        term: request.term
                    },
                    success: function (data) {
                        console.log('Received ' + data.length + ' suggestions');
                        response(data);
                    },
                    error: function (xhr, status, error) {
                        console.error('Error fetching suggestions:', error);
                        response([]);
                    }
                });
            },
            minLength: 2,
            delay: 300,
            appendTo: $searchField.parent(),
            position: {
                my: "left top",
                at: "left bottom",
                collision: "none"
            },
            open: function () {
                console.log('Autocomplete opened');
                // Ensure dropdown matches input width and has high z-index
                const inputWidth = $searchField.outerWidth();
                $('.ui-autocomplete').css({
                    'width': inputWidth + 'px',
                    'z-index': '9999'
                });
            },
            select: function (event, ui) {
                console.log('Selected:', ui.item.value);
                // When user selects a suggestion
                $searchField.val(ui.item.value);
                return false;
            },
            close: function () {
                console.log('Autocomplete closed');
            }
        });

        // Custom rendering to highlight matching text
        if ($searchField.data("ui-autocomplete")) {
            $searchField.data("ui-autocomplete")._renderItem = function (ul, item) {
                const term = this.term;
                const regex = new RegExp('(' + term.replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + ')', 'gi');
                const highlighted = item.label.replace(regex, '<strong>$1</strong>');

                return $("<li>")
                    .append("<div>" + highlighted + "</div>")
                    .appendTo(ul);
            };
            console.log('Server-side autocomplete initialized successfully');
        } else {
            console.error('Failed to initialize autocomplete');
        }
    }

    // Initialize on page load and Turbolinks load
    $(document).ready(function () {
        console.log('Document ready, initializing autocomplete');
        setTimeout(initializeAutocomplete, 100);
    });

    $(document).on('turbolinks:load', function () {
        console.log('Turbolinks load, initializing autocomplete');
        setTimeout(initializeAutocomplete, 100);
    });

    // Clean up on page unload
    $(document).on('turbolinks:before-cache', function () {
        console.log('Turbolinks before-cache, cleaning up');
        const $searchField = $('#search-field-header');
        if ($searchField.data("ui-autocomplete")) {
            $searchField.autocomplete("destroy");
        }
    });
})();
