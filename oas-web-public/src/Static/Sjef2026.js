import { useQuery, gql } from "@apollo/client"
import { get } from 'lodash'

export const Sjef2026 = () => {

  const { data, error } = useQuery(gql`
    query {
      user {
        id,
        name,
        membership_status
      }
    }
  `)
  console.log("001", data)

  return <div>
    <h1>Sjef workshop 2026</h1>
    <p>Sjef be teaching in Oxford on the 3rd (Good Friday) and 4th (Saturday) of April. He is a renowend acrobat, take this rare opertunity sponge up his abilities. Spaces are limited.</p>
    <h3>Timetable</h3>
    <p>
      Friday the 3rd will be hosted at the <a href="https://oldschoolhouseoxford.org/">Old Schoolhouse</a>:
    </p>
    <ul>
      <li>10.00-10.30: Warm-up</li>
      <li>10.30-11.00: Handstands</li>
      <li>11.00-12.30: Standing F2H entries and exits</li>
      <li>12.30-13.30: Lunch</li>
      <li>13.30-15.00: Reverse H2H</li>
      <li>15.15-16.45: Dynamic trios: swings</li>
      <li>16.45-18.00: Special requests</li>
    </ul>

    <p>
      Saturday the 4th will be hosted at the <a href="https://www.thetenth.co.uk/">Marston Scout hall</a>:
    </p>
    <ul>
      <li>10.00-10.45: Warm-up and handstands</li>
      <li>10.45-12.15: Standing F2H entries and exits</li>
      <li>12.15-13.15: Lunch</li>
      <li>13.15-14.45: Reverse H2H</li>
      <li>14.45-16.15: Dynamic trios: swings</li>
      <li>16.15-18.00: Jam/Special requests</li>
    </ul>

    <h3>Pricing</h3>
    <ul>
      <li>One day: 25 GBP</li>
      <li>Both days: 40 GBP</li>
      {get(data, "user.membership_status") === "MEMBER" && <li>One day as OAS full member: 15 GBP</li>}
      {get(data, "user.membership_status") === "MEMBER" && <li>Both days as OAS full member: 25 GBP</li>}
    </ul>
    <p>
      To book, please fill out our <a href="/register">registration form</a>, then select the days you wish to attend from our <a href="/bookings">bookings page</a>.
      Ignore your account amount if it is incorrect, it will be manually modified by an admin.
      Then pay the expected price to the bank acount whos info you recieved after registration.
    </p>
    <p>
      Please email <a href="mailto:oxfordacrouk@gmail.com">oxfordacrouk@gmail.com</a> for any issues, or join the <a href="https://chat.whatsapp.com/E5bhT4pAwvd2JbM3q27H9c">whatsapp group</a>
    </p>

  </div>

}
