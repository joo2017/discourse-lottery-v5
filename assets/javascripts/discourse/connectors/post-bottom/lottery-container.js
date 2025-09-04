import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { inject as service } from "@ember/service";

export default class LotteryContainer extends Component {
  @service site;
  @tracked lotteryData = null;

  constructor() {
    super(...arguments);
    this.loadLotteryData();
  }

  get shouldDisplay() {
    const post = this.args.outletArgs.model;
    return post?.post_number === 1 && this.lotteryData;
  }

  loadLotteryData() {
    const topic = this.args.outletArgs.model?.topic;
    if (topic?.lottery) {
      this.lotteryData = topic.lottery;
    }
  }
}
