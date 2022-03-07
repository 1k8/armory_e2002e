package armory.logicnode;

import iron.object.Animation;
import iron.object.Object;

class AnimationStateNode extends LogicNode {

	var object: Object;
	var animation: Animation;
	var sampler: ActionSampler;
	public var property0: String;

	public function new(tree: LogicTree) {
		super(tree);
		tree.notifyOnUpdate(init);
	}

	public function init() {
		object = inputs[0].get();
		assert(Error, object != null, "Object input cannot be null");
		animation = object.animation;
		if (animation == null) animation = object.getBoneAnimation(object.uid);
		assert(Error, animation != null, "Object does not have animations");
		sampler = animation.activeActions.get(property0);
		if(sampler == null) return;
		sampler.notifyOnComplete(function (){runOutput(3);});
		tree.removeUpdate(init);
		
	}

	override function get(from: Int): Dynamic {
		if(sampler == null) return null;
		return switch (from) {
			case 0: sampler.action;
			case 1: sampler.offset;
			case 2: sampler.paused;
			default: null;
		}
	}
}
