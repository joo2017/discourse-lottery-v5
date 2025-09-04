import { withPluginApi } from "discourse/lib/plugin-api";
import { ajax } from "discourse/lib/ajax";
// 注意：LotteryWidget 组件的引用已不再需要在此文件中

export default {
  name: "extend-for-lottery",
  
  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");
    
    if (!siteSettings.lottery_enabled) {
      return;
    }
    
    withPluginApi("0.8.31", (api) => {
      // -------------------------------------------------------------------
      // DECORATE WIDGET 代码块已被完全删除，这是本次修改的核心
      // -------------------------------------------------------------------
      
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
            action: "insert
