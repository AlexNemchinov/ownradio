<?php
/*
Plugin Name: com.netvoxlab.ownradio
Description: Broadcast radio ownRadio. Listen to your favorite music only.
Version: 2017.05.29
Author: Ltd. NetVox Lab
Author URI: http://www.netvoxlab.ru/
License: GPLv3

com.netvoxlab.ownradio is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 2 of the License, or
any later version.

com.netvoxlab.ownradio is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with com.netvoxlab.ownradio. If not, see <http://www.gnu.org/licenses/>.
*/

define('NETVOXLAB_OWNRADIO_PLUGIN_VERSION', '2017.05.29');
define('NETVOXLAB_OWNRADIO_PLAYER_URL', plugin_dir_url( __FILE__ ));

global $width;
global $height;

if( is_admin() )
    $my_settings_page = new netvoxlab_ownradio_player_shortcode();

	class netvoxlab_ownradio_player_shortcode {


    /**
     * Start up
     */
    public function __construct()
    {
        add_action( 'admin_menu', array( $this, 'add_plugin_page' ) );
        add_action( 'admin_init', array( $this, 'page_init' ) );
    }

    /**
     * Add options page
     */
    public function add_plugin_page()
    {
        // This page will be under "Settings"
        add_options_page(
            'Settings Admin',
            'ownRadio',
            'manage_options',
            'my-setting-admin',
            array( $this, 'create_admin_page' )
        );
    }

    /**
     * Options page callback
     */
    public function create_admin_page()
    {
        // Set class property
        $this->options = get_option( 'my_option_name' );
        ?>
        <div class="wrap">
            <h1>ownRadio</h1>
            <form method="post" action="options.php">
            <?php
                // This prints out all hidden setting fields
                settings_fields( 'my_option_group' );
                do_settings_sections( 'my-setting-admin' );
                submit_button();
            ?>
            </form>
        </div>
        <?php
    }


    /**
     * Register and add settings
     */
    public function page_init()
    {
        register_setting(
            'my_option_group', // Option group
            'my_option_name', // Option name
            array( $this, 'sanitize' ) // Sanitize
        );

        add_settings_section(
            'setting_section_id', // ID
            'ownRadio Settings', // Title
            array( $this, 'print_section_info' ), // Callback
            'my-setting-admin' // Page
        );

				add_settings_field(
            'box_view',
            'Player view:',
            array( $this, 'box_view_callback' ),
            'my-setting-admin',
            'setting_section_id'
        );
    }

    /**
     * Sanitize each setting field as needed
     *
     *  $input Contains all settings fields as array keys
     */

		 public function sanitize( $input )
    {
        $new_input = array();

				if( isset( $input['box_view'] ) )
            $new_input['box_view'] = sanitize_text_field( $input['box_view'] );

        return $new_input;
    }


    /**
     * Print the Section text
     */
    public function print_section_info()
    {
      print 'This is a radio plugin. Here you can only skeep or pause the song. To display radio on you website use this shortcode: [ownradio_new_player].';
    }


		public function box_view_callback()
    {
      if(get_option('my_option_name')['box_view'] == "small") {
        $smallSelected = "selected";
        $bigSelected = "";
      } else if(get_option('my_option_name')['box_view'] == "big"){
        $smallSelected = "";
        $bigSelected = "selected";
      } else {
        $smallSelected = "";
        $bigSelected = "selected";
      }
      printf(
          '
					<select id="box_view" name="my_option_name[box_view]">
					  <option value="small">Small player</option>
					  <option value="big">Extended player</option>
					</select>
					',
          isset( $this->options['box_view'] ) ? esc_attr( $this->options['box_view']) : ''
      );
    }

		static $netvoxlab_ownradio_add_script;

		static function init () {
			add_shortcode('ownradio_player', array(__CLASS__, 'netvoxlab_ownradio_player_func'));
			add_shortcode('ownradio_new_player', array(__CLASS__, 'netvoxlab_ownradio_new_player_func'));
			add_shortcode('ownradio_vkcomment', array(__CLASS__, 'nvxOwnRadioPrintVKCommenScripts_func'));
			add_shortcode('ownradio_GetUserDevices', array(__CLASS__, 'nvxOwnRadioGetUserDevices_shortcode'));
			add_shortcode('ownradio_GetUsersRating', array(__CLASS__, 'nvxOwnRadioGetUsersRating_shortcode'));
			add_shortcode('ownradio_GetLastTracks', array(__CLASS__, 'nvxOwnRadioGetLastTracks_shortcode'));

			add_shortcode('ownradio_GetLastTracksWithRating', array(__CLASS__, 'nvxOwnRadioGetTracksHistoryByDeviceWithRating_shortcode'));

			add_shortcode('ownradio_GetLastUsers', array(__CLASS__, 'nvxOwnRadioGetLastUsers_shortcode'));

			add_shortcode('ownradio_GetTracksHistory', array(__CLASS__, 'nvxOwnRadioGetTracksHistoryByDevice_shortcode'));
			add_shortcode('ownradio_GetLastDevices', array(__CLASS__, 'nvxOwnRadioGetLastDevices_shortcode'));
			add_action('init', array(__CLASS__, 'netvoxlab_ownradio_register_myscript'));
			add_action( 'wp_footer', array(__CLASS__, 'netvoxlab_ownradio_enqueue_myscript' ));
			add_action('init', array(__CLASS__, 'adminmenu_settings_update'));

		}

		static function adminmenu_settings_update(){
			$options = get_option('netvoxlab_ownradio_player_options');
			if (is_array($options)){
				if (!array_key_exists("nvxownradiourl",$options) or $options["nvxownradiourl"] == "") {
					$options["nvxownradiourl"] = 'https://api.ownradio.ru/v4';
					update_option('netvoxlab_ownradio_player_options', $options);
				}
			} else {
				update_option('netvoxlab_ownradio_player_options',
				array(
					'nvxownradiourl' => 'https://api.ownradio.ru/v4',
				));
			}

			$netvoxlab_ownradio_player_server_url = 'https://api.ownradio.ru/v4'; //$options["nvxownradiourl"];

			$scriptWithVar = "
			<script type=\"text/javascript\">
			var nvxOwnRadioServerUrl = '".$netvoxlab_ownradio_player_server_url."';
			var browserInfo = '".getInfoBrowser()."';
			</script>";

			echo $scriptWithVar;
		}


		static function netvoxlab_ownradio_new_player_func ($atts, $content = null)
	 {

		 $nextBut = plugin_dir_url( __FILE__ ) . "assets/next.svg";
		 $playBut = plugin_dir_url( __FILE__ ) . "assets/but1.svg";
		 $pauseBut = plugin_dir_url( __FILE__ ) . "assets/pause.svg";
		 $exPicture = plugin_dir_url( __FILE__ ) . "assets/pic.png";
		 $appBut = plugin_dir_url( __FILE__ ) . "assets/app.svg";
		 $googleBut = plugin_dir_url( __FILE__ ) . "assets/gp.svg";
     $logo = plugin_dir_url( __FILE__ ) . "assets/tx.svg";


		 $boxView = get_option('my_option_name')['box_view'];

     self::$netvoxlab_ownradio_add_script = true;


     if ($boxView == "small") {
       $hiddenClass = "hidden";
       $boxWidth = "400px";
       $boxHeight = "40px";
       $position = "block";
       $netvoxlab_ownradio_wfm_sign = '

               <div class="ownRadioPlayer-new-track small-player" id="ownRadio-player" style="background-color: rgba(211, 235, 255, 1); margin:10px;width:'.$boxWidth.'; height:'.$boxHeight.'">

                  <img src="'.$logo.'" class="logo-pic '.$hiddenClass.'" style="width:180px; height:80px"/>

                    <div class="ownRadioPlayer-play" id="radioPlay"></div>
                   <div class="track-det small-det">
                     <div class="ownRadioPlayer-group small-group" id="radioName" style="white-space: unset;"></div>
                     <div class="det-break"> - </div>
                     <div class="ownRadioPlayer-name small-name" id="radioGroup"></div>
                   </div>



                    <div class="ownRadioPlayer-nextButton small-next" id="radioNext"><div class="ownRadioPlayer-next"></div></div>

                     <div class="progress-block '.$hiddenClass.'" style="width: 95%; margin-top: 40px;">

                       <div class="ownProgress-bar" id="radioProgress">
                         <div class="bar" id="myBar"></div>
                       </div>

                       <div class="time-block">
                         <div id="current-time"></div>
                         <div id="track-time"></div>
                       </div>

                   </div>


                 <div class="'.$hiddenClass.' desc_block right-side">

                   <div class="extended-class" style="padding: 20px">

                     <div class="" style="color: black">
                      <h2>Просто радио.</h2>
                       <div class="app-desc">Это радио, а не проигрыватель и поэтому здесь нельзя вернуться к ранее проигранному треку, нельзя перематывать, можно лишь пропустить.то что вам не нравится.</div>
                        <div class="flex media">
                          <a class="btn appstore" href="https://itunes.apple.com/app/ownradio/id1179868370?mt=8">	<img src="'.$appBut.'"/></a>
                          <a class="btn appstore" href="https://itunes.apple.com/app/ownradio/id1179868370?mt=8"><img src="'.$googleBut.'"/></a>
                        </div>
                      </div>
                   </div>

                 </div>
             </div>

          ';
     } else {
       $hiddenClass = "flex";
       $boxWidth = "600px";
       $boxHeight = "450px";
       $position = "block";
       $netvoxlab_ownradio_wfm_sign = '

               <div class="ownRadioPlayer-new-track ownRadio-player" id="ownRadio-player" style="background-color: rgba(211, 235, 255, 1); margin:10px;width:'.$boxWidth.'; height:'.$boxHeight.'">

                  <div class="player-block left-side">
                    <img src="'.$logo.'" class="logo-pic" style="width:180px; height:80px"/>
                   <div class="track-det">
                     <div class="ownRadioPlayer-group" id="radioName" style="white-space: unset;"></div>
                     <div class="ownRadioPlayer-name" id="radioGroup"></div>
                   </div>

                   <div style="display: '.$position.'; width: 100%; text-align: -webkit-center !important;">

                     <div id="radioPlay" class="play-but radioPlay">
                       <img src="'.$pauseBut.'" class="image-block"  id="radioPlayB" style="width:80px; height:80px"/>
                       <img src="'.$playBut.'" class="image-block " id="radioPause" style="width:80px; height:80px"/>
                     </div>
                      <img src="'.$nextBut.'" class="image-block radioNext" id="radioNext" style="width:50px; height:50px"/>

                     <div class="progress-block"style="width: 95%; margin-top: 40px;">

                       <div class="ownProgress-bar" id="radioProgress">
                         <div class="bar" id="myBar"></div>
                       </div>

                       <div class="time-block">
                         <div id="current-time"></div>
                         <div id="track-time"></div>
                       </div>
                     </div>
                   </div>
                  </div>

                 <div class="'.$hiddenClass.' desc_block right-side">

                   <div class="extended-class" style="padding: 20px">

                     <div class="" style="color: black">
                      <h2>Просто радио.</h2>
                       <div class="app-desc">Это радио, а не проигрыватель и поэтому здесь нельзя вернуться к ранее проигранному треку, нельзя перематывать, можно лишь пропустить.то что вам не нравится.</div>
                        <div class="flex media">
                          <a class="media-btn" href="https://itunes.apple.com/app/ownradio/id1179868370?mt=8">	<img class="media-pict" src="'.$appBut.'"/></a>
                          <a class="media-btn" href="https://play.google.com/store/apps/details?id=ru.netvoxlab.ownradio"><img class="media-pict" src="'.$googleBut.'"/></a>
                        </div>
                      </div>
                   </div>

                 </div>
             </div>

          ';
     }


		 return $content . $netvoxlab_ownradio_wfm_sign ;
	 }
	 static function netvoxlab_ownradio_register_myscript(){
		 wp_register_script('netvoxlab-ownradio-script', NETVOXLAB_OWNRADIO_PLAYER_URL . 'assets/js/scripts.js', [], NETVOXLAB_OWNRADIO_PLUGIN_VERSION);
		 wp_register_script('netvoxlab-ownradio-script', NETVOXLAB_OWNRADIO_PLAYER_URL . 'assets/js/statisticsScripts.js', [], NETVOXLAB_OWNRADIO_PLUGIN_VERSION);
		 wp_register_style('netvoxlab-ownradio-style', NETVOXLAB_OWNRADIO_PLAYER_URL . 'assets/css/ownRadio.min.css', [], NETVOXLAB_OWNRADIO_PLUGIN_VERSION);
	 }

	 static function netvoxlab_ownradio_enqueue_myscript() {
		 if ( !self::$netvoxlab_ownradio_add_script ) return;
		 wp_enqueue_style('netvoxlab-ownradio-style', NETVOXLAB_OWNRADIO_PLAYER_URL . 'assets/css/ownRadio.min.css');
		 wp_enqueue_script( 'netvoxlab-ownradio-script', NETVOXLAB_OWNRADIO_PLAYER_URL . 'assets/js/scripts.js' );
		 wp_enqueue_script( 'netvoxlab-ownradio-script', NETVOXLAB_OWNRADIO_PLAYER_URL . 'assets/js/statisticsScripts.js' );

	 }

	 //функция возвращает все устройства пользователя
	 static function nvxOwnRadioGetUserDevices_shortcode ($atts, $content = null) {
		 self::$netvoxlab_ownradio_add_script = true;
		 return $content . '<div id="nvxUserDevices" class="">
			 <form name="nvxFormaGetUserDevices">
				 <input type="button" onclick="return nvxGetUserDevices(nvxFormaGetUserDevices.userID.value);" value="Получить список всех устройств пользователя">
				 <input type="text" title="Введите userID" name="userID" id="nvxTxtUserID" placeholder="Введите userID" required style="min-width: 280px;">

			 </form>
			 <div id="nvxOwnradioSQLGetRequests">
			 </div>
		 </div>';
	 }

	 //функция просмотра рейтинга пользователей по количеству своих треков и количеству полученных за последние сутки треков
	 static function nvxOwnRadioGetUsersRating_shortcode ($atts, $content = null) {
		 self::$netvoxlab_ownradio_add_script = true;
		 return $content . '<div id="nvxUsersRating" class="">
			 <input type="button" onclick="return nvxBtnUsersRating()" value="Получить рейтинг активности пользователей">
			 <!--<input type="text" title="Введите количество выводимых записей (-1 для вывода всех)" name="countRows" id="nvxTxtCountRows" placeholder="Введите количество выводимых записей(-1 для вывода всех записей)" value = "-1" required>
			 -->

			 <div id="nvxOwnradioSQLGetRequests">
			 </div>
		 </div>';
	 }

	 //функция просмотра последних выданных устройству треков
	 static function nvxOwnRadioGetLastTracks_shortcode ($atts, $content = null) {
		 self::$netvoxlab_ownradio_add_script = true;
		 return $content . '<div id="nvxLastDeviceTracks" class="">
			 <form name="nvxFormaLastDeviceTracks">
				 <input type="button" onclick="return nvxGetLastTracks(nvxFormaLastDeviceTracks.deviceId.value, nvxFormaLastDeviceTracks.countRows.value)" value="Получить последние выданные треки">
				 <input type="text" title="Введите deviceId" name="deviceId" id="nvxTxtDeviceId" placeholder="Введите deviceId" required style="min-width: 280px;">
				 <input type="text" title="Введите количество выводимых записей (-1 для вывода всех)" name="countRows" id="nvxTxtCountRows" placeholder="Введите количество выводимых записей(-1 для вывода всех записей)" value = "-1" required>

			 </form>
			 <div id="nvxOwnradioSQLGetRequests">
			 </div>
		 </div>';
	 }


	 //функция просмотра последних выданных устройству треков и истории их прослушивания
	 static function nvxOwnRadioGetTracksHistoryByDevice_shortcode ($atts, $content = null) {
		 self::$netvoxlab_ownradio_add_script = true;
		 return $content . '<div id="nvxLastDeviceTracks" class="">
			 <form name="nvxFormaTracksHistory">
				 <input type="button" onclick="return nvxGetTracksHistory(nvxFormaTracksHistory.deviceId.value, nvxFormaTracksHistory.countRows.value)" value="Получить последние выданные треки">
				 <input type="text" title="Введите deviceId" name="deviceId" id="nvxTxtDeviceId" placeholder="Введите deviceId" required style="min-width: 280px;">
				 <input type="text" title="Введите количество выводимых записей (-1 для вывода всех)" name="countRows" id="nvxTxtCountRows" placeholder="Введите количество выводимых записей(-1 для вывода всех записей)" value = "-1" required>
			 </form>
			 <div id="nvxOwnradioSQLGetRequests">
			 </div>
		 </div>';
	 }

	 //функция просмотра последних выданных устройству треков и их рейтинг
	 static function nvxOwnRadioGetTracksHistoryByDeviceWithRating_shortcode ($atts, $content = null) {
		 self::$netvoxlab_ownradio_add_script = true;
		 return $content . '<div id="nvxLastDeviceTracks" class="">
			 <form name="nvxFormaTracksHistoryWithRating">
				 <input type="button" onclick="return nvxGetTracksHistoryWithRating(nvxFormaTracksHistory.deviceId.value, nvxFormaTracksHistory.countRows.value)" value="Получить последние выданные треки">
				 <input type="text" title="Введите deviceId" name="deviceId" id="nvxTxtDeviceId" placeholder="Введите deviceId" required style="min-width: 280px;">
				 <input type="text" title="Введите количество выводимых записей (-1 для вывода всех)" name="countRows" id="nvxTxtCountRows" placeholder="Введите количество выводимых записей(-1 для вывода всех записей)" value = "-1" required>
			 </form>
			 <div id="nvxOwnradioSQLGetRequests">
			 </div>
		 </div>';
	 }

	 //функция возвращает последние активные устройства
	 static function nvxOwnRadioGetLastDevices_shortcode ($atts, $content = null) {
		 self::$netvoxlab_ownradio_add_script = true;
		 return $content . '<div id="nvxGetLastDevices" class="">
			 <form name="nvxFormaLastDevices">
				 <input type="button" onclick="return nvxBtnLastDevice()" value="Просмотреть последние активные устройства">
			 </form>
			 <div id="nvxOwnradioSQLGetRequests">
			 </div>
		 </div>';
	 }

	 //функция возвращает последниx активных пользователей
	 static function nvxOwnRadioGetLastUsers_shortcode ($atts, $content = null) {
		 self::$netvoxlab_ownradio_add_script = true;
		 return $content . '<div id="nvxGetLastUsers" class="">
			 <form name="nvxFormaLastUsers">
				 <input type="button" onclick="return nvxBtnLastUsers()" value="Просмотреть последних активных пользователей">
			 </form>
			 <div id="nvxOwnradioSQLGetRequests">
			 </div>
		 </div>';
	 }

	 //функция выводит скрипт комментирования вк
	 static function nvxOwnRadioPrintVKCommenScripts_func($atts, $content = null) {
		 self::$netvoxlab_ownradio_add_script = true;
		 $atts = shortcode_atts( array(
		 'id' => '5978191',
		 'limit' => '20'
		 ), $atts ) ;
		 return $content . '<!-- Put this script tag to the <head> of your page -->
			 <script type="text/javascript" src="//vk.com/js/api/openapi.js?144"></script>

			 <script type="text/javascript">
				 VK.init({apiId:'. esc_html($atts['id']) .', onlyWidgets: true});
			 </script>

			 <!-- Put this div tag to the place, where the Comments block will be -->
			 <div id="vk_comments"></div>
			 <script type="text/javascript">
				 VK.Widgets.Comments("vk_comments", {limit:' .esc_html($atts['limit']). ', attach: "*"});
			 </script>';
		 }
	 }

	 //функция получает имя и версию используемого браузера
	 function getInfoBrowser(){
		 $agent = $_SERVER['HTTP_USER_AGENT'];
		 preg_match("/(Edge|Opera|Firefox|Chrome|Version)(?:\/| )([0-9.]+)/", $agent, $bInfo);
		 $browserInfo = array();
		 if(strpos($agent, 'Edge')) {
			 $browserInfo['name'] = 'MS Edge';
			 $browserInfo['version'] = substr($agent, strpos($agent, 'Edge')+5, 7);
		 }
		 else {
			 $browserInfo['name'] = ($bInfo[1]=="Version") ? "Safari" : $bInfo[1];
			 $browserInfo['version'] = $bInfo[2];
		 }
		 return $browserInfo['name']. " v." . $browserInfo['version'];
	 }

	 // netvoxlab_ownradio_player_shortcode::init();

	 if (is_admin()){
		 //Добавляем меню в админку
		 // include_once('nvxownradioadminmenu.php');
	 } else {
		 // include_once('nvxOwnradioShotcodes.php');
		 netvoxlab_ownradio_player_shortcode::init();
		 // nvxOwnradioShotcodes::init();
	 }


	 ?>
