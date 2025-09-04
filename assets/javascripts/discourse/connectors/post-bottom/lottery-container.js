import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";

export default class LotteryContainer extends Component {
  // this.args.outletArgs.model 是从插件出口传递过来的 Post 对象
  get post() {
    return this.args.outletArgs.model;
  }
  
  // 从 Post 对象中获取 Topic 数据
  get topic() {
    return this.post?.topic;
  }

  // 从 Topic 数据中获取我们的抽奖数据
  get lotteryData() {
    return this.topic?.lottery;
  }

  // 这是决策逻辑：当且仅当这是第一个帖子且包含抽奖数据时，才显示组件
  get shouldDisplay() {
    return this.post?.post_number === 1 && this.lotteryData;
  }
}
