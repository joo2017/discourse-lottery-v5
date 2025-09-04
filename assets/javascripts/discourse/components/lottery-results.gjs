import Component from "@glimmer/component";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import UserLink from "discourse/components/user-link";
import formatDate from "discourse/helpers/format-date";
import I18n from "I18n";

export default class LotteryResults extends Component {
  <template>
    <div class="lottery-results">
      <div class="results-header">
        <h4>{{I18n.t "lottery.results.title"}}</h4>
        <div class="results-summary">
          {{I18n.t "lottery.results.summary" count=@lottery.winners.length}}
        </div>
      </div>
      
      {{#if this.isCurrentUserWinner}}
        <div class="winner-congratulations">
          🎉 {{htmlSafe this.congratulationsMessage}}
        </div>
      {{/if}}
      
      {{#if this.hasWinners}}
        <div class="winners-list">
          {{#each this.winnerPositions as |winner|}}
            <div class="winner-item position-{{winner.position}}">
              <span class="winner-emoji">{{winner.emoji}}</span>
              <div class="winner-info">
                <div class="winner-position">{{winner.positionText}}</div>
                <div class="winner-user">
                  <UserLink @user={{winner.user}} />
                </div>
                <div class="winner-time">
                  {{I18n.t "lottery.results.drawn_at"}} {{formatDate winner.drawn_at format="medium"}}
                </div>
              </div>
            </div>
          {{/each}}
        </div>
      {{else}}
        <div class="no-winners">
          {{I18n.t "lottery.results.no_winners"}}
        </div>
      {{/if}}
      
      <div class="verification-info">
        <details>
          <summary>{{I18n.t "lottery.results.verification_title"}}</summary>
          <div class="verification-content">
            <p>{{I18n.t "lottery.results.verification_desc"}}</p>
            <div class="verification-data">
              <strong>{{I18n.t "lottery.results.lottery_id"}}:</strong> {{@lottery.id}}<br>
              <strong>{{I18n.t "lottery.results.draw_time"}}:</strong> {{formatDate @lottery.drawn_at format="full"}}<br>
              <strong>{{I18n.t "lottery.results.participant_count"}}:</strong> {{@lottery.participant_count}}<br>
              <strong>{{I18n.t "lottery.results.draw_method"}}:</strong> {{I18n.t (concat "lottery.draw_type." @lottery.draw_type)}}
            </div>
          </div>
        </details>
      </div>
    </div>
  </template>
  
  @service currentUser;
  
  get winners() {
    return this.args.lottery.winners || [];
  }
  
  get hasWinners() {
    return this.winners.length > 0;
  }
  
  get isCurrentUserWinner() {
    if (!this.currentUser) return false;
    return this.winners.some(winner => winner.user.id === this.currentUser.id);
  }
  
  get winnerPositions() {
    const positions = ["🥇", "🥈", "🥉"];
    return this.winners.map((winner, index) => ({
      ...winner,
      emoji: positions[index] || "🏆",
      positionText: I18n.t("lottery.results.position", { position: winner.position })
    }));
  }
  
  get congratulationsMessage() {
    if (!this.isCurrentUserWinner) return null;
    
    const userWinner = this.winners.find(w => w.user.id === this.currentUser.id);
    return I18n.t("lottery.results.congratulations", { position: userWinner.position });
  }
}
