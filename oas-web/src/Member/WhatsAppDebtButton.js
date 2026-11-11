import { IconButton } from '@mui/material';
import WhatsAppIcon from '@mui/icons-material/WhatsApp';
import { gql, useQuery } from '@apollo/client';
import { get } from 'lodash';
import { buildWhatsAppDebtLink, isInDebt } from './whatsappDebtReminder';

const CONFIG_QUERY = gql`
  query {
    config_config {
      id
      name
      bacs
      currency
      phone_country_code
    }
  }
`;

// Shown only when the member is in debt. Opens WhatsApp with a pre-filled
// reminder; the admin reviews and sends it themselves.
export const WhatsAppDebtButton = ({ member }) => {
  const inDebt = isInDebt(member);
  const { data } = useQuery(CONFIG_QUERY, { skip: !inDebt });

  if (!inDebt) {
    return null;
  }

  const link = buildWhatsAppDebtLink(member, get(data, 'config_config', {}) || {});

  if (!link) {
    return <span title={`${member.name} has no valid phone number`}>
      <IconButton disabled>
        <WhatsAppIcon />
      </IconButton>
    </span>;
  }

  return <IconButton
    title={`Send ${member.name} a debt reminder on WhatsApp`}
    component="a"
    href={link}
    target="_blank"
    rel="noopener noreferrer"
  >
    <WhatsAppIcon sx={{ color: '#25D366' }} />
  </IconButton>;
};
