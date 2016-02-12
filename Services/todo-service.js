var module = swim.module('todo');

module.service('todo', function () {
  var todo = this.ListLane("todo/list");
});

module.route({prefix: '/todo/', service: 'todo'});
