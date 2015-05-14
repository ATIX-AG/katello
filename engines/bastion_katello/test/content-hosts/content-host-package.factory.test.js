describe('Factory: ContentHostPackage', function() {
    var $httpBackend,
        task,
        packages,
        ContentHostPackage;

    beforeEach(module('Bastion.content-hosts', 'Bastion.utils', 'Bastion.test-mocks'));

    beforeEach(module(function($provide) {
        packages = {
            records: [
                { name: 'kernel', id: 1 },
                { name: 'firefox', id: 2 }
            ],
            total: 2,
            subtotal: 2
        };
        task = {id: 'task_id'};
    }));

    beforeEach(inject(function($injector) {
        $httpBackend = $injector.get('$httpBackend');
        ContentHostPackage = $injector.get('ContentHostPackage');
    }));

    afterEach(function() {
        $httpBackend.flush();
    });

    it('provides a way to get a list of packages', function() {
        $httpBackend.expectGET('/katello/api/v2/systems/SYS_ID/packages').respond(packages);
        ContentHostPackage.get({ id: 'SYS_ID' }, function(results) {
            expect(results.total).toBe(2);
        });
    });

    it('provides a way to install a list of packages', function() {
        $httpBackend.expectPUT('/katello/api/v2/systems/SYS_ID/packages/install').respond(task);
        ContentHostPackage.install({ uuid: 'SYS_ID', packages: ['kernel'] }, function(results) {
            expect(results.id).toBe(task.id);
        });
    });

    it('provides a way to update a list of packages', function() {
        $httpBackend.expectPUT('/katello/api/v2/systems/SYS_ID/packages/upgrade').respond(task);
        ContentHostPackage.update({ uuid: 'SYS_ID', packages: ['kernel'] }, function(results) {
            expect(results.id).toBe(task.id);
        });
    });

    it('provides a way to update all of packages', function() {
        $httpBackend.expectPUT('/katello/api/v2/systems/SYS_ID/packages/upgrade_all').respond(task);
        ContentHostPackage.updateAll({ uuid: 'SYS_ID', packages: ['kernel'] }, function(results) {
            expect(results.id).toBe(task.id);
        });
    });

    it('provides a way to remove a list of packages', function() {
        $httpBackend.expectPUT('/katello/api/v2/systems/SYS_ID/packages/remove').respond(task);
        ContentHostPackage.remove({ uuid: 'SYS_ID', packages: ['kernel'] }, function(results) {
            expect(results.id).toBe(task.id);
        });
    });

});
