import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action, fn } from "@ember/object";
import { on } from "@ember/modifier";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/components/d-button";
import TextField from "discourse/components/text-field";
import Textarea from "discourse/components/textarea";
import ComboBox from "select-kit/components/combo-box";
import DateTimeInput from "discourse/components/date-time-input";
import I18n from "I18n";

export default class LotteryEntryForm extends Component {
  @service siteSettings;
  @service currentUser;
  
  @tracked title = "";
  @tracked description = "";
  @tracked winnerCount = 1;
  @tracked minParticipants = this.siteSettings.lottery_min_participants_global || 5;
  @tracked endTime = null;
  @tracked drawType = "random";
  @tracked specificPosts = "";
  @tracked strategyWhenInsufficient = "cancel";
  @tracked prizeInfo = "";
  @tracked loading = false;
  @tracked errors = {};
  
  get drawTypeOptions() {
    return [
      { id: "random", name: I18n.t("lottery.draw_type.random") },
      { id: "specific_posts", name: I18n.t("lottery.draw_type.specific_posts") }
    ];
  }
  
  get strategyOptions() {
    return [
      { id: "cancel", name: I18n.t("lottery.strategy.cancel") },
      { id: "proceed", name: I18n.t("lottery.strategy.proceed") }
    ];
  }
  
  get isSpecificPostsDraw() {
    return this.drawType === "specific_posts";
  }
  
  get canSubmit() {
    return this.title.trim() &&
           this.winnerCount > 0 &&
           this.minParticipants >= (this.siteSettings.lottery_min_participants_global || 1) &&
           this.endTime &&
           !this.loading;
  }
  
  get minParticipantsMin() {
    return this.siteSettings.lottery_min_participants_global || 1;
  }
  
  @action
  updateDrawType(type) {
    this.drawType = type;
    if (type === "specific_posts") {
      this.specificPosts = "";
    }
  }
  
  @action
  updateSpecificPosts(event) {
    const value = event.target.value;
    this.specificPosts = value;
    
    // 自动计算获奖人数
    if (value.trim()) {
      const posts = value.split(",").map(p => p.trim()).filter(p => /^\d+$/.test(p));
      this.winnerCount = posts.length;
    }
  }
  
  @action
  validateMinParticipants() {
    const min = this.minParticipantsMin;
    if (this.minParticipants < min) {
      this.minParticipants = min;
    }
  }
  
  @action
  async submit(event) {
    event.preventDefault();
    this.errors = {};
    
    if (!this.validate()) {
      return;
    }
    
    this.loading = true;
    
    try {
      const data = {
        lottery: {
          title: this.title.trim(),
          description: this.description.trim(),
          winner_count: this.winnerCount,
          min_participants: this.minParticipants,
          end_time: this.endTime,
          draw_type: this.drawType,
          specific_posts: this.isSpecificPostsDraw ? this.specificPosts.trim() : null,
          strategy_when_insufficient: this.strategyWhenInsufficient,
          prize_info: this.prizeInfo.trim()
        },
        topic_id: this.args.topicId
      };
      
      const result = await ajax("/lottery/create", {
        type: "POST",
        data: data
      });
      
      this.args.onSuccess?.(result);
    } catch (error) {
      if (error.jqXHR?.responseJSON?.errors) {
        this.errors = { general: error.jqXHR.responseJSON.errors.join(", ") };
      } else {
        popupAjaxError(error);
      }
    } finally {
      this.loading = false;
    }
  }
  
  @action
  cancel() {
    this.args.onCancel?.();
  }
  
  validate() {
    const errors = {};
    
    if (!this.title.trim()) {
      errors.title = I18n.t("lottery.errors.title_required");
    }
    
    if (this.winnerCount < 1) {
      errors.winnerCount = I18n.t("lottery.errors.winner_count_invalid");
    }
    
    if (this.minParticipants < this.minParticipantsMin) {
      errors.minParticipants = I18n.t("lottery.errors.min_participants_too_low", { min: this.minParticipantsMin });
    }
    
    if (!this.endTime) {
      errors.endTime = I18n.t("lottery.errors.end_time_required");
    } else if (new Date(this.endTime) <= new Date()) {
      errors.endTime = I18n.t("lottery.errors.end_time_must_be_future");
    }
    
    if (this.isSpecificPostsDraw) {
      if (!this.specificPosts.trim()) {
        errors.specificPosts = I18n.t("lottery.errors.specific_posts_required");
      } else {
        const posts = this.specificPosts.split(",").map(p => p.trim());
        if (!posts.every(p => /^\d+$/.test(p))) {
          errors.specificPosts = I18n.t("lottery.errors.specific_posts_format");
        }
      }
    }
    
    this.errors = errors;
    return Object.keys(errors).length === 0;
  }

  <template>
    <div class="lottery-entry-form">
      <form {{on "submit" this.submit}}>
        {{#if this.errors.general}}
          <div class="alert alert-error">
            {{this.errors.general}}
          </div>
        {{/if}}
        
        <div class="form-group">
          <label for="lottery-title">{{I18n.t "lottery.form.title"}} <span class="required">*</span></label>
          <TextField
            @value={{this.title}}
            @placeholderKey="lottery.form.title_placeholder"
            id="lottery-title"
            maxlength="255"
          />
          {{#if this.errors.title}}
            <div class="error-message">{{this.errors.title}}</div>
          {{/if}}
        </div>
        
        <div class="form-group">
          <label for="lottery-description">{{I18n.t "lottery.form.description"}}</label>
          <Textarea
            @value={{this.description}}
            @placeholderKey="lottery.form.description_placeholder"
            id="lottery-description"
            rows="3"
          />
        </div>
        
        <div class="form-group">
          <label for="lottery-prize-info">{{I18n.t "lottery.form.prize_info"}}</label>
          <TextField
            @value={{this.prizeInfo}}
            @placeholderKey="lottery.form.prize_info_placeholder"
            id="lottery-prize-info"
          />
        </div>
        
        <div class="form-row">
          <div class="form-group">
            <label for="lottery-draw-type">{{I18n.t "lottery.form.draw_type"}} <span class="required">*</span></label>
            <ComboBox
              @value={{this.drawType}}
              @content={{this.drawTypeOptions}}
              @onChange={{this.updateDrawType}}
              id="lottery-draw-type"
            />
          </div>
          
          {{#unless this.isSpecificPostsDraw}}
            <div class="form-group">
              <label for="lottery-winner-count">{{I18n.t "lottery.form.winner_count"}} <span class="required">*</span></label>
              <TextField
                @value={{this.winnerCount}}
                @type="number"
                min="1"
                max="50"
                id="lottery-winner-count"
              />
              {{#if this.errors.winnerCount}}
                <div class="error-message">{{this.errors.winnerCount}}</div>
              {{/if}}
            </div>
          {{/unless}}
        </div>
        
        {{#if this.isSpecificPostsDraw}}
          <div class="form-group">
            <label for="lottery-specific-posts">{{I18n.t "lottery.form.specific_posts"}} <span class="required">*</span></label>
            <TextField
              @value={{this.specificPosts}}
              @placeholderKey="lottery.form.specific_posts_placeholder"
              id="lottery-specific-posts"
              {{on "input" this.updateSpecificPosts}}
            />
            <div class="help-text">
              {{I18n.t "lottery.form.specific_posts_help"}}
            </div>
            {{#if this.errors.specificPosts}}
              <div class="error-message">{{this.errors.specificPosts}}</div>
            {{/if}}
          </div>
          
          {{#if this.winnerCount}}
            <div class="form-info">
              {{I18n.t "lottery.form.calculated_winners" count=this.winnerCount}}
            </div>
          {{/if}}
        {{/if}}
        
        <div class="form-row">
          <div class="form-group">
            <label for="lottery-min-participants">{{I18n.t "lottery.form.min_participants"}} <span class="required">*</span></label>
            <TextField
              @value={{this.minParticipants}}
              @type="number"
              min={{this.minParticipantsMin}}
              max="1000"
              id="lottery-min-participants"
              {{on "blur" this.validateMinParticipants}}
            />
            <div class="help-text">
              {{I18n.t "lottery.form.min_participants_help" min=this.minParticipantsMin}}
            </div>
            {{#if this.errors.minParticipants}}
              <div class="error-message">{{this.errors.minParticipants}}</div>
            {{/if}}
          </div>
          
          <div class="form-group">
            <label for="lottery-strategy">{{I18n.t "lottery.form.strategy_when_insufficient"}} <span class="required">*</span></label>
            <ComboBox
              @value={{this.strategyWhenInsufficient}}
              @content={{this.strategyOptions}}
              @onChange={{fn (mut this.strategyWhenInsufficient)}}
              id="lottery-strategy"
            />
          </div>
        </div>
        
        <div class="form-group">
          <label for="lottery-end-time">{{I18n.t "lottery.form.end_time"}} <span class="required">*</span></label>
          <DateTimeInput
            @date={{this.endTime}}
            @onChange={{fn (mut this.endTime)}}
            id="lottery-end-time"
          />
          {{#if this.errors.endTime}}
            <div class="error-message">{{this.errors.endTime}}</div>
          {{/if}}
        </div>
        
        <div class="form-actions">
          <DButton
            @action={{this.submit}}
            @disabled={{not this.canSubmit}}
            @icon="plus"
            class="btn-primary"
            type="submit"
          >
            {{I18n.t "lottery.form.create"}}
          </DButton>
          
          <DButton
            @action={{this.cancel}}
            @icon="times"
            class="btn-secondary"
          >
            {{I18n.t "lottery.form.cancel"}}
          </DButton>
        </div>
      </form>
    </div>
  </template>
}
