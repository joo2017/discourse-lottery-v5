import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import LotteryCountdown from "./lottery-countdown";
import LotteryResults from "./lottery-results";
import LotteryEntryForm from "./lottery-entry-form";
import I18n from "I18n";

export default class LotteryWidget extends Component {
  @service currentUser;
  @service siteSettings;
  @service messageBus;
  
  @tracked lottery = this.args.lottery;
  @tracked isParticipating = false;
  @tracked showCreateForm = false;
  @tracked loading = false;
  
  constructor() {
    super(...arguments);
    this.setupMessageBus();
  }
  
  willDestroy() {
    super.willDestroy(...arguments);
    if (this.lottery?.id) {
      this.messageBus.unsubscribe(`/lottery/${this.lottery.id}`);
    }
  }
  
  setupMessageBus() {
    if (!this.lottery?.id) return;
    
    this.messageBus.subscribe(`/lottery/${this.lottery.id}`, (data) => {
      switch (data.type) {
        case "participant_joined":
        case "participant_left":
          this.lottery.participant_count = data.participant_count;
          break;
        case "draw_completed":
          this.lottery.status = "completed";
          this.lottery.winners = data.winners;
          break;
        case "cancelled":
          this.lottery.status = "cancelled";
          break;
      }
    });
  }
  
  get canParticipate() {
    return this.lottery?.can_participate && this.currentUser && !this.userParticipated;
  }
  
  get userParticipated() {
    return this.lottery?.user_participated;
  }
  
  get isActive() {
    return this.lottery?.status === "active";
  }
  
  get isCompleted() {
    return this.lottery?.status === "completed";
  }
  
  get isCancelled() {
    return this.lottery?.status === "cancelled";
  }
  
  get statusClass() {
    return `lottery-status-${this.lottery?.status}`;
  }
  
  get progressPercent() {
    if (!this.lottery) return 0;
    return Math.min((this.lottery.participant_count / this.lottery.min_participants) * 100, 100);
  }
  
  @action
  async participate() {
    if (!this.currentUser) {
      this.showLogin();
      return;
    }
    
    this.loading = true;
    
    try {
      const result = await ajax(`/lottery/${this.lottery.id}/participate`, {
        type: "POST"
      });
      
      if (result.success) {
        this.lottery.participant_count = result.participant_count;
        this.lottery.user_participated = true;
        this.showToast("success", I18n.t("lottery.participate.success"));
      }
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.loading = false;
    }
  }
  
  @action
  async leave() {
    this.loading = true;
    
    try {
      const result = await ajax(`/lottery/${this.lottery.id}/leave`, {
        type: "DELETE"
      });
      
      if (result.success) {
        this.lottery.participant_count = result.participant_count;
        this.lottery.user_participated = false;
        this.showToast("success", I18n.t("lottery.leave.success"));
      }
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.loading = false;
    }
  }
  
  @action
  showCreateForm() {
    this.showCreateForm = true;
  }
  
  @action
  hideCreateForm() {
    this.showCreateForm = false;
  }
  
  @action
  onLotteryCreated(lottery) {
    this.lottery = lottery;
    this.showCreateForm = false;
    this.showToast("success", I18n.t("lottery.create.success"));
  }
  
  showLogin() {
    this.args.showLogin?.();
  }
  
  showToast(type, message) {
    if (this.args.showToast) {
      this.args.showToast(type, message);
    }
  }

  <template>
    <div class="lottery-widget {{this.statusClass}}">
      {{#if this.lottery}}
        <div class="lottery-header">
          <h3 class="lottery-title">{{this.lottery.title}}</h3>
          <div class="lottery-status">
            {{#if this.isActive}}
              <span class="status-badge active">{{I18n.t "lottery.status.active"}}</span>
            {{else if this.isCompleted}}
              <span class="status-badge completed">{{I18n.t "lottery.status.completed"}}</span>
            {{else if this.isCancelled}}
              <span class="status-badge cancelled">{{I18n.t "lottery.status.cancelled"}}</span>
            {{/if}}
          </div>
        </div>
        
        {{#if this.lottery.description}}
          <div class="lottery-description">
            {{this.lottery.description}}
          </div>
        {{/if}}
        
        {{#if this.lottery.prize_info}}
          <div class="lottery-prize-info">
            <strong>{{I18n.t "lottery.prize_info"}}:</strong> {{this.lottery.prize_info}}
          </div>
        {{/if}}
        
        <div class="lottery-details">
          <div class="detail-item">
            <span class="label">{{I18n.t "lottery.winner_count"}}:</span>
            <span class="value">{{this.lottery.winner_count}}</span>
          </div>
          <div class="detail-item">
            <span class="label">{{I18n.t "lottery.participants"}}:</span>
            <span class="value">{{this.lottery.participant_count}} / {{this.lottery.min_participants}}</span>
          </div>
        </div>
        
        <div class="lottery-progress">
          <div class="progress-bar">
            <div class="progress-fill" style="width: {{this.progressPercent}}%"></div>
          </div>
          <div class="progress-text">
            {{I18n.t "lottery.progress" count=this.lottery.participant_count min=this.lottery.min_participants}}
          </div>
        </div>
        
        {{#if this.isActive}}
          <LotteryCountdown @endTime={{this.lottery.end_time}} @onExpired={{this.onExpired}} />
        {{/if}}
        
        {{#if this.isActive}}
          <div class="lottery-actions">
            {{#if this.canParticipate}}
              <DButton
                @action={{this.participate}}
                @disabled={{this.loading}}
                @icon="ticket-alt"
                class="btn-primary participate-btn"
              >
                {{I18n.t "lottery.participate.button"}}
              </DButton>
            {{else if this.userParticipated}}
              <div class="participated-status">
                <span class="participated-text">
                  {{I18n.t "lottery.participate.already_participated"}}
                </span>
                <DButton
                  @action={{this.leave}}
                  @disabled={{this.loading}}
                  @icon="times"
                  class="btn-danger leave-btn"
                >
                  {{I18n.t "lottery.leave.button"}}
                </DButton>
              </div>
            {{else if (not this.currentUser)}}
              <DButton
                @action={{this.showLogin}}
                @icon="sign-in-alt"
                class="btn-primary"
              >
                {{I18n.t "lottery.login_required"}}
              </DButton>
            {{else}}
              <div class="cannot-participate">
                {{I18n.t "lottery.cannot_participate"}}
              </div>
            {{/if}}
          </div>
        {{/if}}
        
        {{#if this.isCompleted}}
          <LotteryResults @lottery={{this.lottery}} />
        {{/if}}
        
        {{#if this.isCancelled}}
          <div class="lottery-cancelled">
            <span class="cancelled-text">{{I18n.t "lottery.cancelled.message"}}</span>
          </div>
        {{/if}}
      {{else}}
        <div class="no-lottery">
          {{#if this.currentUser}}
            <DButton
              @action={{this.showCreateForm}}
              @icon="plus"
              class="btn-primary"
            >
              {{I18n.t "lottery.create.button"}}
            </DButton>
          {{else}}
            <p>{{I18n.t "lottery.no_lottery"}}</p>
          {{/if}}
        </div>
      {{/if}}
      
      {{#if this.showCreateForm}}
        <DModal
          @title={{I18n.t "lottery.create.title"}}
          @closeModal={{this.hideCreateForm}}
          class="lottery-create-modal"
        >
          <:body>
            <LotteryEntryForm
              @topicId={{this.args.topicId}}
              @onSuccess={{this.onLotteryCreated}}
              @onCancel={{this.hideCreateForm}}
            />
          </:body>
        </DModal>
      {{/if}}
    </div>
  </template>
}
