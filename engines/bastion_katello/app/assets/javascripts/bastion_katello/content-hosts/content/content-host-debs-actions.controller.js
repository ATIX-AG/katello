/**
 * @ngdoc object
 * @name  Bastion.content-hosts.controller:ContentHostDebsActionsController
 *
 * @requires $scope
 * @requires translate
 * @requires $location
 *
 * @description
 *   Provides the functionality for the content host deb package actions.
 */
angular.module('Bastion.content-hosts').controller('ContentHostDebsActionsController',
    ['$scope', 'translate', '$location', function ($scope, translate, $location) {
        // Labels so breadcrumb strings can be translated
        $scope.label = translate('Deb Package Actions');
        var packageName = $location.search().package_name;
        $scope.packageAction = {actionType: 'packageInstall'};  // default to packageInstall

        if (packageName) {
            $scope.packageAction.term = packageName;
        }
    }
]);
