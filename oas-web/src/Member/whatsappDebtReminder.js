// Builds a wa.me link with a pre-filled debt reminder for a member.
// Nothing is sent automatically: the link opens WhatsApp and the admin presses send.

// Numbers stored in national format (e.g. 07700 900123) are assumed to be UK.
const DEFAULT_COUNTRY_CODE = '44';

export const normalizePhoneForWhatsApp = (phone) => {
  if (!phone) {
    return null;
  }
  const trimmed = `${phone}`.trim();
  let digits = trimmed.replace(/\D/g, '');
  if (!digits) {
    return null;
  }
  if (trimmed.startsWith('+')) {
    // already international
  } else if (digits.startsWith('00')) {
    digits = digits.slice(2);
  } else if (digits.startsWith('0')) {
    digits = DEFAULT_COUNTRY_CODE + digits.slice(1);
  }
  return digits.length >= 8 ? digits : null;
};

export const getDebt = (member) => {
  const credit = parseFloat(member?.credit_amount);
  const tokens = parseInt(member?.token_count, 10);
  return {
    credit: !isNaN(credit) && credit < 0 ? -credit : 0,
    tokens: !isNaN(tokens) && tokens < 0 ? -tokens : 0
  };
};

export const isInDebt = (member) => {
  const { credit, tokens } = getDebt(member);
  return credit > 0 || tokens > 0;
};

export const buildDebtReminderMessage = (member, config = {}) => {
  const { credit, tokens } = getDebt(member);
  const clubName = config?.name;

  const owed = [];
  if (credit > 0) {
    owed.push(`£${credit.toFixed(2)} in credits`);
  }
  if (tokens > 0) {
    owed.push(`${tokens} token${tokens === 1 ? '' : 's'}`);
  }

  const lines = [
    `Just a friendly reminder${clubName ? ` from ${clubName}` : ''} that your account is currently in debt: you owe ${owed.join(' and ')}.`
  ];

  const bacs = `${config?.bacs || ''}`.trim();
  if (bacs) {
    lines.push('', 'You can pay by bank transfer to:', bacs);
  }

  return lines.join('\n');
};

export const buildWhatsAppDebtLink = (member, config) => {
  const phone = normalizePhoneForWhatsApp(member?.member_details?.phone);
  if (!phone) {
    return null;
  }
  return `https://wa.me/${phone}?text=${encodeURIComponent(buildDebtReminderMessage(member, config))}`;
};
