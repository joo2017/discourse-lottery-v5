import { withPluginApi } from "discourse/lib/plugin-api";
import { ajax } from "discourse/lib/ajax";

export default {
  name: "extend-for-lottery",
  
  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");
    
    if (!siteSettings.lottery_enabled) {
      return;
    }
    
    withPluginApi("0.8.31", (api) => {
      //
      // 旧的 api.decorateWidget 调用已从此文件中【彻底删除】
      //
      
      // 注册抽奖组件
      api.registerCustomPostMessageCallback("lottery", (topicController) => {
        const topicModel = topicController.get("model");
        
        // 重新加载主题以获取最新的抽奖数据
        ajax(`/t/${topicModel.id}.json`).then((result) => {
          if (result.lottery) {
            topicModel.set("lottery", result.lottery);
          }
        });
      });
      
      // 添加创建抽奖按钮到编辑器工具栏
      api.addToolbarPopupMenuOptionsCallback((controller) => {
        const composerModel = controller.get("model");
        
        if (composerModel.get("creatingTopic")) {
          return {
            action: "insertLotteryBBCode",
            icon: "ticket-alt",
            label: "lottery.composer.add_lottery",
            condition: siteSettings.lottery_enabled
          };
        }
      });
      
      // 处理插入抽奖 BBCode
      api.modifyClass("controller:composer", {
        pluginId: "discourse-lottery-v5",
        
        actions: {
          insertLotteryBBCode() {
            const bbcode = '[lottery]\n请在此处填写抽奖详情\n[/lottery]';
            this.get("toolbarEvent").addText(bbcode);
          }
        }
      });
      
      // 扩展用户卡片显示抽奖统计
      api.includePostAttributes("lottery_id");
      
      // 添加抽奖相关的用户菜单项
      api.addUserMenuGlyph((widget) => {
        if (widget.currentUser) {
          return {
            label: "lottery.menu.my_lotteries",
            icon: "ticket-alt",
            href: "/lottery/user/" + widget.currentUser.id
          };
        }
      });
      
      // 监听消息总线事件
      api.onPageChange(() => {
        const messageBus = container.lookup("service:message-bus");
        
        // 订阅抽奖相关事件
        messageBus.subscribe("/lottery", (data) => {
          if (data.type === "lottery_created" || data.type === "lottery_updated") {
            // 刷新当前页面的抽奖数据
            const currentRoute = container.lookup("service:router").currentRoute;
            if (currentRoute.name === "topic" && currentRoute.params.id == data.topic_id) {
              window.location.reload();
            }
          }
        });
      });
    });
  }
};
