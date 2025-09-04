// assets/javascripts/discourse/initializers/extend-for-lottery.js
import { withPluginApi } from "discourse/lib/plugin-api";
import { withSilencedDeprecations } from "discourse/lib/deprecated";
import LotteryWidget from "../components/lottery-widget";
import Component from "@glimmer/component";

export default {
  name: "extend-for-lottery",
  
  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");
    
    if (!siteSettings.lottery_enabled) {
      return;
    }
    
    withPluginApi("1.8.0", (api) => {
      // ✅ 新的 Glimmer 组件方式 - 在帖子内容后显示抽奖组件
      api.renderAfterWrapperOutlet(
        "post-content-cooked-html",
        class extends Component {
          static shouldRender(args) {
            const post = args.post;
            return post?.post_number === 1 && post?.topic?.lottery;
          }

          <template>
            <LotteryWidget
              @lottery={{@post.topic.lottery}}
              @topicId={{@post.topic.id}}
              @postId={{@post.id}}
            />
          </template>
        }
      );

      // ✅ 添加抽奖相关的帖子属性跟踪
      api.addTrackedPostProperties('lottery_id', 'has_lottery');

      // ✅ 添加创建抽奖按钮到编辑器工具栏（如果需要）
      api.addComposerToolbarPopupMenuOption({
        icon: "gift",
        label: "lottery.composer.add_lottery",
        condition: () => siteSettings.lottery_enabled,
        action: (toolbarEvent) => {
          const bbcode = '[lottery]\n请在此处填写抽奖详情\n[/lottery]';
          toolbarEvent.addText(bbcode);
        }
      });

      // ✅ 添加抽奖相关的用户菜单项
      api.decorateUserMenu((widget) => {
        if (widget.currentUser) {
          return widget.attach('menu-item', {
            label: 'lottery.menu.my_lotteries',
            icon: 'gift',
            href: `/lottery/user/${widget.currentUser.id}`
          });
        }
      });

      // 🔄 过渡期支持 - 同时支持新旧系统
      withSilencedDeprecations("discourse.post-stream-widget-overrides", () => {
        // 旧的 Widget API 代码（过渡期使用）
        api.decorateWidget("post-contents:after-cooked", (helper) => {
          const post = helper.getModel();
          
          if (post.get("firstPost") && post.topic.lottery) {
            return helper.attach("lottery-widget", {
              lottery: post.topic.lottery,
              topicId: post.topic.id,
              postId: post.id
            });
          }
        });

        // 旧的自定义消息回调
        api.registerCustomPostMessageCallback("lottery", (topicController) => {
          const topicModel = topicController.get("model");
          
          ajax(`/t/${topicModel.id}.json`).then((result) => {
            if (result.lottery) {
              topicModel.set("lottery", result.lottery);
            }
          });
        });
      });
    });
  }
};
