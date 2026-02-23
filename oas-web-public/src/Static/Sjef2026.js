import { useQuery, gql } from "@apollo/client"
import { get } from 'lodash'
import sjefImage from './Sjef2026.png'

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

  return <div style={{paddingBottom: "128px"}}>
    <h1 style={{textAlign: "center"}}>Easter Acro Workshops with Sjef Baas</h1>
    <p style={{textAlign: "center"}}>Oxford, 3rd (Good Friday) and 4th (Saturday) of April 2026</p>
    <p>This Easter we are hosting a two-day workshop delivered by Sjef Baas.</p>
    <p>Sjef came across circus when he was 9 years old and never looked back. Growing up in the Netherlands, he learned from all the best Dutch teachers. He has been a circus acro teacher himself for 10+ years now, sharing his expertise and lifelong fascination with movement and balance.</p>

    <div style={{ display: 'flex', alignItems: 'flex-start', flexWrap: 'wrap', gap: '20px' }}>
      <div style={{ flex: 1, minWidth: '300px' }}>
        <h3>Schedule</h3>
        <ul>
          <li>10.00-10.30: Warm-up</li>
          <li>10.30-11.00: Handstands</li>
          <li>11.00-12.30: Standing F2H entries and exits</li>
          <li>12.30-13.30: Lunch</li>
          <li>13.30-14.45: Reverse H2H</li>
          <li>14.45-16.15: Dynamic trios: swings</li>
          <li>16.15-18.00: Special requests</li>
          <li>Social</li>
        </ul>

        <ul>
          <li>10.00-10.15: Warm-up</li>
          <li>10.15-10.45: Handstands</li>
          <li>10.45-12.15: Standing H2H</li>
          <li>12.15-13.15: Lunch</li>
          <li>13.15-14.45: Dutch Icarian</li>
          <li>14.45-16.15: Dynamic trios: tempo</li>
          <li>16.15-18.00: Jam/Special requests</li>
          <li>Social</li>
        </ul>
        <h3>Tickets</h3>
        <ul>
          <li>Both days: 40 GBP</li>
          <li>One day: 25 GBP</li>
          {get(data, "user.membership_status") === "MEMBER" && <li>Both days as OAS full member: 25 GBP</li>}
          {get(data, "user.membership_status") === "MEMBER" && <li>One day as OAS full member: 15 GBP</li>}

        </ul>
      </div>
      <div style={{ flex: 1, display: 'flex', justifyContent: 'center', minWidth: '300px' }}>
        <img src={sjefImage} style={{ maxWidth: '100%', height: '500px', objectFit: 'contain' }} alt="Sjef" />
      </div>
    </div>

    <h3>Booking</h3>
    <p>
      Please fill out our <a href="/register">registration form</a>, then select the days you wish to attend from our <a href="/bookings">bookings page</a> (Ignore the amount of credits displayed as charged – it will be manually modified by an admin).
       Then pay the expected price to the OAS bank (you received the details at registration).
    </p>
    <p>
      Unfortunately, we will not be able to issue refunds in case of cancellations, but ticket swaps will be possible at individual request.
    </p>
    <h3>Venue</h3>
    <div style={{ display: 'flex', alignItems: 'flex-start', flexWrap: 'wrap', gap: '20px', marginBottom: '20px' }}>
      <div style={{ flex: 1, minWidth: '300px' }}>
        <p>
          This workshop will take place in <a href="https://www.thetenth.co.uk/">Marston Scout hall</a>:<br />
          Marston Scout Hall,<br /> 238 Marston Road,<br />OX3 0EJ,<br />Oxford
        </p>
        <p>
          Street parking is available close to the hall. (There is no designated parking for the venue).
        </p>
        <h3>Food</h3>
        <p>
          Please, bring your own lunch and snacks. There are some shops nearby (a small Londis just across the road, two slightly larger Cooperatives – 10-15min walk), but the opening hours may be limited on bank holidays.
        </p>
        <p>
          We have access to a well-equipped kitchen, where you will be able to heat up ready meals or make hot drinks.
        </p>
        <p>
          Alternatively, you can grab food from the local pub, just across the road: <a href="https://dodopubs.com/locations/the-up-in-arms/">Up in arms</a>. (Needless to say, please, refrain from
          drinking alcohol until you have finished doing acro for the day).
        </p>
      </div>
      <div style={{ flex: 1, minWidth: '300px' }}>
        <iframe
          width="100%"
          height="400"
          style={{ border: 0 }}
          loading="lazy"
          allowFullScreen
          src="https://maps.google.com/maps?q=Marston%20Scout%20Hall,%20Marston%20Road,%20Oxford&t=&z=15&ie=UTF8&iwloc=&output=embed"
          title="Marston Scout Hall Google Map"
        ></iframe>
      </div>
    </div>

    <h3>Contact us</h3>
    <p>If you have any questions, please, email us at <a href="mailto:oxfordacrouk@gmail.com">oxfordacrouk@gmail.com</a>.</p>
    <p>
      For current updates and informal chat about anything connected with the event, join the  <a href="https://chat.whatsapp.com/E5bhT4pAwvd2JbM3q27H9c">whatsapp group</a>. There, you can also connect with other attending acrobats for sharing accommodation and transport.
    </p>
  </div>

}
