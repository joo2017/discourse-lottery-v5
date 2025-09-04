import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { cancel, later } from "@ember/runloop";
import { service } from "@ember/service";
import I18n from "I18n";

export default class LotteryCountdown extends Component {
  @service clock;
  
  @tracked timeRemaining = 0;
  @tracked expired = false;
  
  timer = null;
  
  constructor() {
    super(...arguments);
    this.updateTimeRemaining();
    this.startTimer();
  }
  
  willDestroy() {
    super.willDestroy(...arguments);
    this.stopTimer();
  }
  
  @action
  updateTimeRemaining() {
    const endTime = new Date(this.args.endTime);
    const now = new Date();
    const remaining = endTime - now;
    
    if (remaining <= 0) {
      this.timeRemaining = 0;
      this.expired = true;
      this.stopTimer();
      this.args.onExpired?.();
    } else {
      this.timeRemaining = remaining;
      this.expired = false;
    }
  }
  
  startTimer() {
    this.timer = later(() => {
      this.updateTimeRemaining();
      if (!this.expired) {
        this.startTimer();
      }
    }, 1000);
  }
  
  stopTimer() {
    if (this.timer) {
      cancel(this.timer);
      this.timer = null;
    }
  }
  
  get formattedTime() {
    if (this.expired) {
      return I18n.t("lottery.countdown.expired");
    }
    
    const totalSeconds = Math.floor(this.timeRemaining / 1000);
    const days = Math.floor(totalSeconds / 86400);
    const hours = Math.floor((totalSeconds % 86400) / 3600);
    const minutes = Math.floor((totalSeconds % 3600) / 60);
    const seconds = totalSeconds % 60;
    
    if (days > 0) {
      return I18n.t("lottery.countdown.format_days", { days, hours, minutes });
    } else if (hours > 0) {
      return I18n.t("lottery.countdown.format_hours", { hours, minutes, seconds });
    } else {
      return I18n.t("lottery.countdown.format_minutes", { minutes, seconds });
    }
  }
  
  get urgencyClass() {
    if (this.expired) return "expired";
    
    const totalMinutes = Math.floor(this.timeRemaining / 60000);
    if (totalMinutes < 60) return "urgent";
    if (totalMinutes < 1440) return "warning";
    return "normal";
  }

  <template>
    <div class="lottery-countdown {{this.urgencyClass}}">
      <div class="countdown-icon">
        {{#if this.expired}}
          ⏰
        {{else}}
          🕐
        {{/if}}
      </div>
      <div class="countdown-text">
        <strong>{{I18n.t "lottery.countdown.label"}}:</strong>
        <span class="time-display">{{this.formattedTime}}</span>
      </div>
    </div>
  </template>
}
