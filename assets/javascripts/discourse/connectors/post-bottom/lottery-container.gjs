import LotteryWidget from "discourse/plugins/discourse-lottery-v5/discourse/components/lottery-widget";
import LotteryContainer from "./lottery-container";

<template>
  {{#if this.shouldDisplay}}
    <LotteryWidget @lottery={{this.lotteryData}} @topicId={{this.lotteryData.topic.id}} />
  {{/if}}
</template>
