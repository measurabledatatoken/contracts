$(function() {
  var MIN_LOCKUP_AMOUNT = 625;
  var LOCKUP_END = true;

  if (LOCKUP_END) {
    hideLockupSection();
  }

  // format number with commas
  var numberWithCommas = function (x) {
    var parts = x.toString().split('.');
    parts[0] = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, ',');
    return parts.join('.');
  };

  // format date string for both English and Simplified Chinese
  function formatDate(date, lang) {
    var monthNames = [
      "January", "February", "March",
      "April", "May", "June", "July",
      "August", "September", "October",
      "November", "December"
    ];

    var day = date.getDate();
    var monthIndex = date.getMonth();
    var year = date.getFullYear();

    return lang === 'cn' ? year + '年' + (monthIndex+1) + '月' + day + '日' :
      monthNames[monthIndex] + ' ' + day  + ', ' + year ;
  }

  var validNumber = new RegExp(/^\d*\.?\d*$/);
  var lastValid = document.getElementById('input-lock-amount').value;
  function validateNumber(elem) {
    if (validNumber.test(elem.value)) {
      lastValid = elem.value;
    } else {
      elem.value = lastValid;
    }
  }

  function calculateTokensWithBonus(amount, lockupPeriod) {
    var bonusPercent;
    switch (lockupPeriod) {
      case LockupPeriod.THREE_MONTH:
        bonusPercent = 0.1;
        break;
      case LockupPeriod.SIX_MONTH:
        bonusPercent = 0.3;
        break;
      case LockupPeriod.ONE_YEAR:
        bonusPercent = 0.66;
        break;
    }
    return amount + amount * bonusPercent;
  }

  function lockupPeriodToMonth(lockupPeriod) {
    var month = 3;
    switch (lockupPeriod) {
      case LockupPeriod.THREE_MONTH:
        month = 3;
        break;
      case LockupPeriod.SIX_MONTH:
        month = 6;
        break;
      case LockupPeriod.ONE_YEAR:
        month = 12;
        break;
    }
    return month;
  }

  function handleLockupAmountChanged() {
    var val = $('#input-lock-amount').val();
    if (val === '') {
      $('#mdt-amount-error').hide();
    } else {
      var lockupAmount = parseFloat(val);
      if (lockupAmount >= MIN_LOCKUP_AMOUNT && lockupAmount <= TokenLockupApp.getAvailableLockupAmount()) {
        $('#mdt-amount-error').hide();
      } else {
        $('#mdt-amount-error').show();
      }
    }
    updateConfirmationSection();
  }

  function toFixedIfHasDecimal(value, decimalPlace) {
    if (Math.round(value) !== value) {
      return value.toFixed(decimalPlace);
    }
    return value;
  }

  function updateConfirmationSection() {
    var lockupAmount = parseFloat($('#input-lock-amount').val());
    var lockupPeriod = $('#lockup-form input[type=radio][name=lockup-option]:checked').val();
    if (lockupAmount >= MIN_LOCKUP_AMOUNT &&
      lockupAmount <= TokenLockupApp.getAvailableLockupAmount() &&
      lockupPeriod !== undefined) {
      $('#confirm-button').prop('disabled', false);
      $('#lockup-combination-error').hide();
      $('#lockup-confirmation').show();

      var tokensWithBonus = calculateTokensWithBonus(lockupAmount, lockupPeriod);
      $('#lockup-confirmation .lockup-mdt').text(numberWithCommas(lockupAmount));
      $('#lockup-confirmation .lockup-final').text(numberWithCommas(toFixedIfHasDecimal(tokensWithBonus, 2)));
      $('#lockup-confirmation .lockup-time').text(lockupPeriodToMonth(lockupPeriod));
    } else {
      $('#confirm-button').prop('disabled', true);
      $('#lockup-combination-error').show();
      $('#lockup-confirmation').hide();
    }
  }

  function hideLockupConfirmationAlert() {
    $('#alert-lockup-success').hide();
    $('#alert-lockup-fail').hide();
  }

  $('form').submit(function(e) {
    e.preventDefault();
  });

  $('#input-lock-amount').on('input', function() {
    hideLockupConfirmationAlert();
    validateNumber(this);
    // show alert if the input is invalid
    handleLockupAmountChanged();
  });

  // lockup option on change event
  $('#lockup-form input[type=radio][name=lockup-option]').change(function() {
    hideLockupConfirmationAlert();
    updateConfirmationSection();
  });

  // $('#lockall-button').prop('disabled', false);

  // Lock all button
  $('#lockall-button').click(function() {
    hideLockupConfirmationAlert();
    var maxAvailableAmount = TokenLockupApp.getAvailableLockupAmount();
    $('#input-lock-amount').val(maxAvailableAmount);
    handleLockupAmountChanged();
  });

  // confirm and lock button
  $('#confirm-button').click(function() {
    var lockupAmount = web3.toWei(parseFloat($('#input-lock-amount').val()));
    // console.log('lockup amount:', lockupAmount);
    var lockupPeriod = $('#lockup-form input[type=radio][name=lockup-option]:checked').val();
    // console.log(lockupPeriod);

    // hide confirmation alert
    hideLockupConfirmationAlert();

    // disable buttons and input
    setLockupStepsSectionEnabled(false);
    $('#confirm-button').prop('disabled', true);

    // show loader
    $('#confirm-loader').show();

    // lock tokens
    TokenLockupApp.lockupTokens(lockupAmount, lockupPeriod)
      .catch(function(err) {
        console.log(err);
        return false;
      }).then(function(success) {
        if (success) {
          $('#alert-lockup-success').show();
          // update locked tokens section
          updateLockedTokensSection();
        } else {
          $('#alert-lockup-fail').show();
          setLockupStepsSectionEnabled(true);
          $('#confirm-button').prop('disabled', false);
        }
      }).then(function() {
        // hide loader
        $('#confirm-loader').hide();
      });
  });

  function withdrawTokens(isPrivateSale) {
    var sectionID = isPrivateSale ? '#private-lockup' : '#bird-lockup';
    // hide all alerts
    $(sectionID + ' .alert').hide();
    // disable withdraw button
    $(sectionID + ' button').prop('disabled', true);
    // show loader
    $(sectionID + ' .loader').show();
    TokenLockupApp.withdrawTokens(isPrivateSale)
      .catch(function(err) {
        console.log(err);
        return false;
      }).then(function(success) {
        if (success) {
          $(sectionID + ' .alert-withdraw-success').show();
        } else {
          $(sectionID + ' .alert-withdraw-fail').show();
          $(sectionID + ' button').prop('disabled', false);
        }
      }).then(function() {
        // hide loader
        $(sectionID + ' .loader').hide();
      });
  }

  // early and late bird token withdraw button
  $('#bird-lockup button').click(function() {
    withdrawTokens(false);
  });

  // private sale token withdraw button
  $('#private-lockup button').click(function() {
    withdrawTokens(true);
  });

  function isEventEnded() {
    return LOCKUP_END || TokenLockupApp.eventEnded;
  }

  function handleError(err) {
    $('#tokens-not-locked-error').show();
    var sectionID = isEventEnded() ? '#locked-tokens-section-after' : '#lockup-header-section';
    if (err && err.type !== undefined) {
      switch (err.type) {
        case AppError.METAMASK_NOT_INSTALLED:
          $(sectionID + ' .alert-no-metamask').show();
          return;
        case AppError.METAMASK_LOCKED:
          $(sectionID + ' .alert-metamask-locked').show();
          return;
        case AppError.FAILED_LOADING_CONTRACT:
          $(sectionID + ' .alert-contract-error').show();
          return;
      }
    }
    $(sectionID + ' .alert-system-error').show();
  }

  function showAccountAddress() {
    if (!TokenLockupApp.account) return;
    var sectionID = isEventEnded() ? '#locked-tokens-section-wallet-info' : '#lockup-section-wallet-info';
    $(sectionID + ' .user-wallet').text(TokenLockupApp.account);
  }

  function showNoRecordAlert() {
    var sectionID = isEventEnded() ? '#locked-tokens-section-after' : '#lockup-header-section';
    $(sectionID + ' .alert-no-record').show();
  }

  function showEligibleLockupMessage() {
    var availableAmount = TokenLockupApp.getAvailableLockupAmount();
    var maxLockupAmount = TokenLockupApp.maxLockupAmount;
    $('#success-available .available-mdt').text(numberWithCommas(availableAmount));
    $('#success-available .max-mdt').text(numberWithCommas(maxLockupAmount));
    $('#success-available').show();
  }

  function hideAllAlerts() {
    // hide all alerts
    $('.alert').hide();
  }

  function hideLockupSection() {
    $('#lockup-header-section').hide();
    $('#lockup-steps-section').hide();
    $('#locked-tokens-section-after').show();
    $('#locked-tokens-section').addClass('simple-top');
  }

  function setLockupStepsSectionEnabled(enabled) {
    $('#input-lock-amount').prop('disabled', !enabled);
    $('#lockall-button').prop('disabled', !enabled);
    $('#lockup-form input[type=radio][name=lockup-option]').prop('disabled', !enabled);
  }

  function setLockupStepsSectionVisibility(visible) {
    if (visible) {
      $('#lockup-steps-section').show();
    } else {
      $('#lockup-steps-section').hide();
    }
  }

  function updateLockedTokensDetails(isPrivateSale) {
    var sectionID = isPrivateSale ? '#private-lockup' : '#bird-lockup';
    var record = isPrivateSale ? TokenLockupApp.privateSaleLockupRecord : TokenLockupApp.earlyLateBirdLockupRecord;
    var lockedAmount = record.value;
    var lockupPeriodInMonths = lockupPeriodToMonth(record.lockupPeriod);
    var tokensWithBonus = calculateTokensWithBonus(lockedAmount, record.lockupPeriod);
    // console.log(record);
    $(sectionID + ' .locked-mdt').text(numberWithCommas(toFixedIfHasDecimal(lockedAmount, 2)));
    $(sectionID + ' .locked-time').text(lockupPeriodInMonths);
    $(sectionID + ' .withdraw-en').text(formatDate(record.endTime, 'en'));
    $(sectionID + ' .withdraw-cn').text(formatDate(record.endTime, 'cn'));
    $(sectionID + ' .locked-final').text(numberWithCommas(toFixedIfHasDecimal(tokensWithBonus, 2)));
    setWithdrawButtonEnabled(TokenLockupApp.canWithdrawTokens(isPrivateSale) && !record.withdrawn, isPrivateSale);
    if (record.withdrawn && !$(sectionID + ' .alert-withdraw-success').is(':visible')) {
      var withdrawnTime = record.withdrawnTime ? record.withdrawnTime : record.endTime;
      $(sectionID + ' .alert-already-withdrew .withdraw-en').text(formatDate(withdrawnTime, 'en'));
      $(sectionID + ' .alert-already-withdrew .withdraw-cn').text(formatDate(withdrawnTime, 'cn'));
      $(sectionID + ' .alert-already-withdrew').show();
    } else {
      $(sectionID + ' .alert-already-withdrew').hide();
    }
  }

  function setWithdrawButtonEnabled(enabled, isPrivateSale) {
    var sectionID = isPrivateSale ? '#private-lockup' : '#bird-lockup';
    $(sectionID + ' .withdraw-button').prop('disabled', !enabled);
  }

  function updateLockedTokensSection() {
    var tokensLocked = false;
    // early/late bird locked tokens
    if (TokenLockupApp.hasLockedTokens(false)) {
      $('#bird-lockup').show();
      updateLockedTokensDetails(false);
      tokensLocked = true;
    }

    // private sale locked tokens
    if (TokenLockupApp.hasLockedTokens(true)) {
      $('#private-lockup').show();
      updateLockedTokensDetails(true);
      tokensLocked = true;
    }

    if (tokensLocked) {
      $('#tokens-not-locked-error').hide();
    } else {
      $('#tokens-not-locked-error').show();
    }
  }

  function hideAppLoader() {
    var loaderID = isEventEnded() ? '#locked-tokens-section-loader' : '#lockup-section-loader';
    $(loaderID).hide();
  }

  var MDTOKEN_CONTRACT_ADDRESS = '0x814e0908b12A99FeCf5BC101bB5d0b8B5cDf7d26';
  var MDTOEKN_LOCKUP_CONTRACT_ADDRESS = '0x3c9dd8fac2b908de52363e654fbefe833184a9a0';
  var MDTOKEN_CONTRACT_ABI_URL = 'MDToken.json';
  var MDTOEKN_LOCKUP_CONTRACT_ABI_URL = 'MDTokenLockup.json';

  TokenLockupApp.init(MDTOKEN_CONTRACT_ADDRESS, MDTOKEN_CONTRACT_ABI_URL, MDTOEKN_LOCKUP_CONTRACT_ADDRESS, MDTOEKN_LOCKUP_CONTRACT_ABI_URL)
    .then(function() {
      updateLockedTokensSection();

      if (isEventEnded()) {
        hideLockupSection();
        if (TokenLockupApp.maxLockupAmount <= 0 && !TokenLockupApp.hasLockedTokens(false) && !TokenLockupApp.hasLockedTokens(true)) {
          showNoRecordAlert();
          // hacks to prevent the tokens not locked message shown before the alert
          $('#tokens-not-locked-error').hide();
        }
      } else {
        if (TokenLockupApp.maxLockupAmount <= 0) { // no purchase record for early/late bird
          showNoRecordAlert();
        } else if (TokenLockupApp.hasLockedTokens(false)) { // check if the user has already locked tokens for early/late bird
          setLockupStepsSectionVisibility(false);
          $('#lockup-header-section .alert-already-locked').show();
        } else if (TokenLockupApp.tokenBalance < MIN_LOCKUP_AMOUNT) { // token balance is less than the minimum lockup amount
          showEligibleLockupMessage();
          $('#lockup-header-section .alert-mdt-min').show();
        } else { // enable lockup
          showEligibleLockupMessage();
          setLockupStepsSectionEnabled(true);
        }
      }
    }).catch(function(error) {
      console.log(error.type, error);
      handleError(error);
      // hacks to prevent the tokens not locked message shown before the alert
      if (isEventEnded()) {
        $('#tokens-not-locked-error').hide();
      }
    }).then(function() {
      hideAppLoader();
      showAccountAddress();
    });
});