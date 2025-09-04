// 更高效的实现，使用计算属性替代部分 helper
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { on } from "@ember/modifier";
import { fn } from "@ember/helper";
import { if as ifHelper } from "@ember/helper";
import { each } from "@ember/helper";
import { concat } from "@ember/helper";

export default class LotteryResults extends Component {
  @service currentUser;
  @tracked isLoading = false;

  // 使用 getter 替代 helper，性能更好
  get formattedResults() {
    if (!this.args.results) return [];
    
    return this.args.results.map(result => ({
      ...result,
      formattedDate: this.formatDate(result.createdAt),
      displayClass: this.getResultDisplayClass(result)
    }));
  }

  get refreshButtonClass() {
    return `btn btn-small${this.isLoading ? ' loading' : ''}`;
  }

  formatDate(date, format = "MMM DD, YYYY") {
    if (!date) return "";
    return moment(date).format(format);
  }

  getResultDisplayClass(result) {
    let baseClass = "lottery-result-item";
    if (result.isWinning) baseClass += " winning";
    if (result.isPending) baseClass += " pending";
    return baseClass;
  }

  @action
  handleResultClick(result) {
    this.args.onResultClick?.(result);
  }

  @action
  async refreshResults() {
    this.isLoading = true;
    try {
      await this.args.onRefresh?.();
    } catch (error) {
      console.error("刷新失败:", error);
    } finally {
      this.isLoading = false;
    }
  }

  <template>
    <div class="lottery-results">
      <div class="lottery-results-header">
        <h3>{{@title}}</h3>
        <button
          {{on "click" this.refreshResults}}
          class={{this.refreshButtonClass}}
          disabled={{this.isLoading}}
        >
          {{#if this.isLoading}}刷新中...{{else}}刷新{{/if}}
        </button>
      </div>

      {{#if this.formattedResults}}
        <div class="lottery-results-list">
          {{#each this.formattedResults as |result|}}
            <div
              class={{result.displayClass}}
              {{on "click" (fn this.handleResultClick result)}}
            >
              <div class="result-content">
                <span class="result-number">{{result.number}}</span>
                <span class="result-prize">{{result.prize}}</span>
              </div>
              <div class="result-meta">
                <span class="result-date">{{result.formattedDate}}</span>
                {{#if result.winner}}
                  <span class="result-winner">
                    获奖者: {{result.winner.username}}
                  </span>
                {{/if}}
              </div>
            </div>
          {{/each}}
        </div>
      {{else}}
        <div class="no-results">
          <p>暂无抽奖结果</p>
        </div>
      {{/if}}
    </div>
  </template>
}
