#if defined _throwing_knives_core_included
 #endinput
#endif
#define _throwing_knives_core_included

#define	KNIFES_BY_STEAL		-2				//**< Получил ножи жертвы при убийстве/Потерял при смерти */
#define	KNIFES_BY_NATIVE	-1				//**< Получил/Потерял другим плагином */
#define	KNIFES_BY_DEFAULT	0				//**< Получил плагином при возрождении (tkc_count) */

/**
 *	Вызывается когда игрок метает нож.
 *	-
 * @param iClient			Индекс игрока.
 *	-
 *	@return true чтобы разрешить, false чтобы заблокировать
*/
forward bool:TKC_OnKnifeThrow(iClient);

/**
 *	Вызывается когда игрок получает ножи.
 *	-
 * @param iClient			Индекс игрока.
 * @param iCount			Количество.
 * @param by_who			Смотреть KNIFES_BY_*.
 *	-
 * @return	Вернуть Plugin_Stop или Plugin_Handled чтобы заблокировать.
 * 			Вернуть Plugin_Changed чтобы разрешить с изменением.
 * 			Вернуть Plugin_Continue чтобы разрешить без изменений.
*/
forward Action:TKC_OnKnifesGiven(iClient, &iCount, by_who);

/**
 *	Вызывается когда игрок теряет ножи.
 *	-
 * @param iClient			Индекс игрока.
 * @param iCount			Количество.
 * @param by_who			Смотреть KNIFES_BY_*.
 *	-
 * @return	Вернуть Plugin_Stop или Plugin_Handled чтобы заблокировать.
 * 			Вернуть Plugin_Changed чтобы разрешить с изменением.
 * 			Вернуть Plugin_Continue чтобы разрешить без изменений.
*/
forward Action:TKC_OnKnifesTaken(iClient, &iCount, by_who);

/**
 *	Получает количество ножей у игрока.
 *	-
 * @param iClient			Индекс игрока.
 *	-
 * @return	Количество ножей, -1 если бесконечно.
*/
native TKC_GetClientKnives(iClient);

/**
 *	Устанавливает количество ножей игроку.
 *	-
 * @param iClient			Индекс игрока.
 * @param iCount			Количество ножей (-1 бесконечно).
 *	-
 * @noreturn
*/
native TKC_SetClientKnives(iClient, iCount);

/**
 *	Добавляет ножи игроку.
 *	-
 * @param iClient			Индекс игрока.
 * @param iCount			Количество ножей.
 *	-
 * @return	true в случае успеха, иначе false.
*/
native bool:TKC_GiveClientKnives(iClient, iCount);

/**
 *	Отнимает ножи у игрока.
 *	-
 * @param iClient			Индекс игрока.
 * @param iCount			Количество ножей.
 *	-
 * @return	true в случае успеха, иначе false.
*/
native bool:TKC_TakeClientKnives(iClient, iCount);

/**
 *	Проверяет является ли сущность ножем.
 *	-
 * @param iEntity			Индекс сущности.
 *	-
 * @return	true если сущность нож, иначе false.
*/
native bool:TKC_IsEntityThrowingKnife(iEntity);

public SharedPlugin:__pl_throwing_knives_core= 
{
	name = "throwing_knives_core",
	file = "Throwing_Knives_Core.smx",
#if defined REQUIRE_PLUGIN
	required = 1
#else
	required = 0
#endif
};