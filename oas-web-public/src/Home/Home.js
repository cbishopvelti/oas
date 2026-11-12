import { useQuery, gql } from "@apollo/client"
import { get } from 'lodash';
import { Fragment } from "react";
import { formatMoney } from '../App/money';
import { useSociety } from '../Society/SocietyProvider';


export const Home = () => {
  const society = useSociety();
  const {data} = useQuery(gql`
    query {
      public_config_tokens {
        token_expiry_days,
        tokens {
          quantity,
          value
        }
      }
      public_config_config {
        content,
        credits,
        currency
      }
    }
  `)

  return <div>
    {society.name && <h1>{society.name}</h1>}

    <div dangerouslySetInnerHTML={{ __html: get(data, "public_config_config.content", "")}}>
    </div>

    {get(data, "public_config_config.credits") && <p>We run a credit system, Credits are non refundable and expire after {get(data, 'public_config_tokens.token_expiry_days', 'loading')} days, but they can be transferred to other members.</p>}

    {!get(data, "public_config_config.credits") && <p>We run a token system. Participating in indoor jams and trainings cost 1 token per session. {get(data, 'public_config_tokens.tokens', []).map(({ value, quantity }, index) => {
      let start = '';
      if (index !== 0) {
        start = ', '
      }
      if (index == get(data, 'public_config_tokens', []).length - 1) {
        start = ' and ';
      }
      return `${index == 0 ? '' : ', '}${quantity} token${quantity != 1 ? 's' : ''} cost${quantity == 1 ? 's' : ''} ${formatMoney(value * quantity, get(data, 'public_config_config.currency'))}`
    })}. Tokens are non refundable and expire after {get(data, 'public_config_tokens.token_expiry_days', 'loading')} days, but they can be transferred to other members.</p>}
  </div>
}
