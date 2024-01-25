import { Link } from "react-router-dom"
import { useQuery, gql } from "@apollo/client"
import { get } from 'lodash';


export const Home = () => {
  const {data} = useQuery(gql`
    query {
      public_config_tokens {
        token_expiry_days,
        tokens {
          quantity,
          value
        }
      }
    }
  `)

  return <div>
    <h1>Oxfordshire Acro Society</h1>
    <p>This is the virtual home of the Oxfordshire Acro Society.</p>
    <p>There are jams in the Winter season at New Marston Scout Hall, OX3 0EJ, 1530 - 1800 on Sundays, all welcome.</p>
    <p>If you are joining for the first time, please go to “register” in the menu and sign up. You can come to 3 sessions as a temporary member before you must become a full member, full membership for this season runs until the 31st of October and is 12 GBP. Please register <Link to="/register">here</Link></p>
    <p>There are training sessions at Oxsrad Sports Centre, OX3 0NQ, 1900 - 2100 on Tuesdays and Thursdays 1915 - 2100 for members only.</p>
    <p>We run a token system. Participating in indoor jams and trainings cost 1 token per session. {get(data, 'public_config_tokens.tokens', []).map(({value, quantity}, index) => {
        let start = '';
        if (index !== 0 ) {
          start = ', '
        }
        if (index == get(data, 'public_config_tokens', []).length - 1) {
          start = ' and ';
        }
        return `${index == 0 ? '' : ', '}${quantity} token${quantity != 1 ? 's': ''} cost${quantity == 1 ? 's' : ''} ${value * quantity} GBP`
      })}. Tokens are non refundable and expire after {get(data, 'public_config_tokens.token_expiry_days' , 'loading')} days, but they can be transferred to other members.</p>
  </div>
}